(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_DATA_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u105))
(define-constant ERR_VOTING_ENDED (err u106))
(define-constant ERR_INVALID_PROPOSAL (err u107))
(define-constant ERR_NOT_MEMBER (err u108))
(define-constant ERR_NOT_PURCHASER (err u109))
(define-constant ERR_ALREADY_RATED (err u110))
(define-constant ERR_INVALID_RATING (err u111))

(define-constant ERR_SUBSCRIPTION_NOT_FOUND (err u112))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u113))
(define-constant ERR_INSUFFICIENT_SUBSCRIPTION_BALANCE (err u114))

(define-constant ERR_INSURANCE_NOT_FOUND (err u115))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u116))
(define-constant ERR_INSURANCE_EXPIRED (err u117))
(define-constant ERR_INSUFFICIENT_INSURANCE_BALANCE (err u118))

(define-data-var insurance-pool-balance uint u0)
(define-data-var next-policy-id uint u1)

(define-data-var next-subscription-id uint u1)

(define-data-var next-data-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var treasury-balance uint u0)

(define-map farmers principal {
    reputation: uint,
    total-earnings: uint,
    data-count: uint,
    joined-at: uint
})

(define-map sensor-data uint {
    farmer: principal,
    data-type: (string-ascii 50),
    location: (string-ascii 100),
    timestamp: uint,
    price: uint,
    sold: bool,
    buyer: (optional principal)
})

(define-map data-purchases uint {
    buyer: principal,
    data-id: uint,
    purchase-price: uint,
    purchased-at: uint
})

(define-map proposals uint {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    voting-ends: uint,
    executed: bool
})

(define-map votes {proposal-id: uint, voter: principal} bool)

(define-public (register-farmer)
    (begin
        (map-set farmers tx-sender {
            reputation: u0,
            total-earnings: u0,
            data-count: u0,
            joined-at: stacks-block-height
        })
        (ok true)
    )
)

(define-public (submit-sensor-data (data-type (string-ascii 50)) (location (string-ascii 100)) (price uint))
    (begin
        (asserts! (is-some (map-get? farmers tx-sender)) ERR_NOT_MEMBER)
        (asserts! (> price u0) ERR_INVALID_AMOUNT)
        (map-set sensor-data (var-get next-data-id) {
            farmer: tx-sender,
            data-type: data-type,
            location: location,
            timestamp: stacks-block-height,
            price: price,
            sold: false,
            buyer: none
        })
        (map-set farmers tx-sender (merge 
            (unwrap-panic (map-get? farmers tx-sender))
            {data-count: (+ (get data-count (unwrap-panic (map-get? farmers tx-sender))) u1)}
        ))
        (var-set next-data-id (+ (var-get next-data-id) u1))
        (ok (- (var-get next-data-id) u1))
    )
)

(define-public (purchase-data (data-id uint))
    (begin
        (asserts! (is-some (map-get? sensor-data data-id)) ERR_DATA_NOT_FOUND)
        (asserts! (not (get sold (unwrap-panic (map-get? sensor-data data-id)))) ERR_DATA_NOT_FOUND)
        (try! (stx-transfer? (get price (unwrap-panic (map-get? sensor-data data-id))) tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? 
            (/ (* (get price (unwrap-panic (map-get? sensor-data data-id))) u80) u100) 
            tx-sender 
            (get farmer (unwrap-panic (map-get? sensor-data data-id)))
        )))
        (var-set treasury-balance (+ (var-get treasury-balance) 
            (/ (* (get price (unwrap-panic (map-get? sensor-data data-id))) u20) u100)
        ))
        (map-set sensor-data data-id (merge 
            (unwrap-panic (map-get? sensor-data data-id))
            {sold: true, buyer: (some tx-sender)}
        ))
        (map-set farmers (get farmer (unwrap-panic (map-get? sensor-data data-id))) (merge 
            (unwrap-panic (map-get? farmers (get farmer (unwrap-panic (map-get? sensor-data data-id)))))
            {
                total-earnings: (+ 
                    (get total-earnings (unwrap-panic (map-get? farmers (get farmer (unwrap-panic (map-get? sensor-data data-id))))))
                    (/ (* (get price (unwrap-panic (map-get? sensor-data data-id))) u80) u100)
                ),
                reputation: (+ 
                    (get reputation (unwrap-panic (map-get? farmers (get farmer (unwrap-panic (map-get? sensor-data data-id))))))
                    u1
                )
            }
        ))
        (ok true)
    )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (recipient principal))
    (begin
        (asserts! (is-some (map-get? farmers tx-sender)) ERR_NOT_MEMBER)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount (var-get treasury-balance)) ERR_INSUFFICIENT_BALANCE)
        (asserts! (>= (get reputation (unwrap-panic (map-get? farmers tx-sender))) u5) ERR_NOT_AUTHORIZED)
        (map-set proposals (var-get next-proposal-id) {
            proposer: tx-sender,
            title: title,
            description: description,
            amount: amount,
            recipient: recipient,
            votes-for: u0,
            votes-against: u0,
            voting-ends: (+ stacks-block-height u144),
            executed: false
        })
        (var-set next-proposal-id (+ (var-get next-proposal-id) u1))
        (ok (- (var-get next-proposal-id) u1))
    )
)

(define-public (vote-proposal (proposal-id uint) (vote-for bool))
    (begin
        (asserts! (is-some (map-get? proposals proposal-id)) ERR_PROPOSAL_NOT_FOUND)
        (asserts! (is-some (map-get? farmers tx-sender)) ERR_NOT_MEMBER)
        (asserts! (< stacks-block-height (get voting-ends (unwrap-panic (map-get? proposals proposal-id)))) ERR_VOTING_ENDED)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
        (asserts! (> (get reputation (unwrap-panic (map-get? farmers tx-sender))) u0) ERR_NOT_AUTHORIZED)
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)
        (if vote-for
            (map-set proposals proposal-id (merge 
                (unwrap-panic (map-get? proposals proposal-id))
                {votes-for: (+ 
                    (get votes-for (unwrap-panic (map-get? proposals proposal-id))) 
                    (get reputation (unwrap-panic (map-get? farmers tx-sender)))
                )}
            ))
            (map-set proposals proposal-id (merge 
                (unwrap-panic (map-get? proposals proposal-id))
                {votes-against: (+ 
                    (get votes-against (unwrap-panic (map-get? proposals proposal-id))) 
                    (get reputation (unwrap-panic (map-get? farmers tx-sender)))
                )}
            ))
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (begin
        (asserts! (is-some (map-get? proposals proposal-id)) ERR_PROPOSAL_NOT_FOUND)
        (asserts! (>= stacks-block-height (get voting-ends (unwrap-panic (map-get? proposals proposal-id)))) ERR_VOTING_ENDED)
        (asserts! (not (get executed (unwrap-panic (map-get? proposals proposal-id)))) ERR_INVALID_PROPOSAL)
        (asserts! (> 
            (get votes-for (unwrap-panic (map-get? proposals proposal-id))) 
            (get votes-against (unwrap-panic (map-get? proposals proposal-id)))
        ) ERR_NOT_AUTHORIZED)
        (try! (as-contract (stx-transfer? 
            (get amount (unwrap-panic (map-get? proposals proposal-id))) 
            tx-sender 
            (get recipient (unwrap-panic (map-get? proposals proposal-id)))
        )))
        (var-set treasury-balance (- 
            (var-get treasury-balance) 
            (get amount (unwrap-panic (map-get? proposals proposal-id)))
        ))
        (map-set proposals proposal-id (merge 
            (unwrap-panic (map-get? proposals proposal-id))
            {executed: true}
        ))
        (ok true)
    )
)

(define-read-only (get-farmer-info (farmer principal))
    (map-get? farmers farmer)
)

(define-read-only (get-sensor-data (data-id uint))
    (map-get? sensor-data data-id)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

(define-read-only (get-farmer-reputation (farmer principal))
    (match (map-get? farmers farmer)
        farmer-data (get reputation farmer-data)
        u0
    )
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
    (is-some (map-get? votes {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (is-data-available (data-id uint))
    (match (map-get? sensor-data data-id)
        data-info (not (get sold data-info))
        false
    )
)

(define-read-only (get-data-count)
    (- (var-get next-data-id) u1)
)

(define-read-only (get-proposal-count)
    (- (var-get next-proposal-id) u1)
)

(define-read-only (get-data-price (data-id uint))
    (match (map-get? sensor-data data-id)
        data-info (some (get price data-info))
        none
    )
)


(define-map data-ratings uint {
    total-ratings: uint,
    total-score: uint,
    average-rating: uint
})

(define-map user-ratings {data-id: uint, rater: principal} uint)

(define-public (rate-data (data-id uint) (rating uint))
    (begin
        (asserts! (is-some (map-get? sensor-data data-id)) ERR_DATA_NOT_FOUND)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
        (asserts! (get sold (unwrap-panic (map-get? sensor-data data-id))) ERR_DATA_NOT_FOUND)
        (asserts! (is-eq tx-sender (unwrap-panic (get buyer (unwrap-panic (map-get? sensor-data data-id))))) ERR_NOT_PURCHASER)
        (asserts! (is-none (map-get? user-ratings {data-id: data-id, rater: tx-sender})) ERR_ALREADY_RATED)
        (map-set user-ratings {data-id: data-id, rater: tx-sender} rating)
        (let ((current-ratings (default-to {total-ratings: u0, total-score: u0, average-rating: u0} 
                                          (map-get? data-ratings data-id))))
            (let ((new-total-ratings (+ (get total-ratings current-ratings) u1))
                  (new-total-score (+ (get total-score current-ratings) rating)))
                (map-set data-ratings data-id {
                    total-ratings: new-total-ratings,
                    total-score: new-total-score,
                    average-rating: (/ (* new-total-score u100) new-total-ratings)
                })
            )
        )
        (ok true)
    )
)

(define-read-only (get-data-rating (data-id uint))
    (map-get? data-ratings data-id)
)

(define-read-only (get-farmer-average-rating (farmer principal))
    (let ((farmer-info (map-get? farmers farmer)))
        (match farmer-info
            info (if (> (get data-count info) u0)
                    (let ((score (get-farmer-quality-score farmer (get data-count info))))
                        (some (/ (get total-score score) (get count score))))
                    (some u0))
            none
        )
    )
)

(define-read-only (get-farmer-quality-score (farmer principal) (data-count uint))
    (fold calculate-farmer-rating (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
          {farmer: farmer, total-score: u0, count: u0, max-check: data-count})
)

(define-private (calculate-farmer-rating (data-id uint) (acc {farmer: principal, total-score: uint, count: uint, max-check: uint}))
    (if (>= (get count acc) (get max-check acc))
        acc
        (match (map-get? sensor-data data-id)
            data-info (if (and (is-eq (get farmer data-info) (get farmer acc))
                              (get sold data-info))
                         (match (map-get? data-ratings data-id)
                             rating-info {
                                 farmer: (get farmer acc),
                                 total-score: (+ (get total-score acc) (get average-rating rating-info)),
                                 count: (+ (get count acc) u1),
                                 max-check: (get max-check acc)
                             }
                             acc)
                         acc)
            acc
        )
    )
)

(define-read-only (has-rated-data (data-id uint) (rater principal))
    (is-some (map-get? user-ratings {data-id: data-id, rater: rater}))
)

(define-read-only (get-user-rating (data-id uint) (rater principal))
    (map-get? user-ratings {data-id: data-id, rater: rater})
)

(define-map subscriptions uint {
    subscriber: principal,
    farmer: principal,
    data-type: (string-ascii 50),
    monthly-fee: uint,
    balance: uint,
    expires-at: uint,
    auto-renew: bool,
    created-at: uint
})

(define-map farmer-subscribers {farmer: principal, subscriber: principal} uint)

(define-public (create-subscription (farmer principal) (data-type (string-ascii 50)) (monthly-fee uint) (initial-payment uint))
    (begin
        (asserts! (is-some (map-get? farmers farmer)) ERR_NOT_MEMBER)
        (asserts! (> monthly-fee u0) ERR_INVALID_AMOUNT)
        (asserts! (>= initial-payment monthly-fee) ERR_INSUFFICIENT_BALANCE)
        (try! (stx-transfer? initial-payment tx-sender (as-contract tx-sender)))
        (let ((subscription-id (var-get next-subscription-id)))
            (map-set subscriptions subscription-id {
                subscriber: tx-sender,
                farmer: farmer,
                data-type: data-type,
                monthly-fee: monthly-fee,
                balance: initial-payment,
                expires-at: (+ stacks-block-height u4320),
                auto-renew: true,
                created-at: stacks-block-height
            })
            (map-set farmer-subscribers {farmer: farmer, subscriber: tx-sender} subscription-id)
            (var-set next-subscription-id (+ subscription-id u1))
            (ok subscription-id)
        )
    )
)

(define-public (access-subscribed-data (subscription-id uint) (data-id uint))
    (begin
        (asserts! (is-some (map-get? subscriptions subscription-id)) ERR_SUBSCRIPTION_NOT_FOUND)
        (asserts! (is-some (map-get? sensor-data data-id)) ERR_DATA_NOT_FOUND)
        (let ((subscription (unwrap-panic (map-get? subscriptions subscription-id)))
              (data (unwrap-panic (map-get? sensor-data data-id))))
            (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_NOT_AUTHORIZED)
            (asserts! (< stacks-block-height (get expires-at subscription)) ERR_SUBSCRIPTION_EXPIRED)
            (asserts! (is-eq (get farmer data) (get farmer subscription)) ERR_NOT_AUTHORIZED)
            (asserts! (is-eq (get data-type data) (get data-type subscription)) ERR_INVALID_PROPOSAL)
            (ok true)
        )
    )
)

(define-public (renew-subscription (subscription-id uint) (payment uint))
    (begin
        (asserts! (is-some (map-get? subscriptions subscription-id)) ERR_SUBSCRIPTION_NOT_FOUND)
        (let ((subscription (unwrap-panic (map-get? subscriptions subscription-id))))
            (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_NOT_AUTHORIZED)
            (asserts! (>= payment (get monthly-fee subscription)) ERR_INSUFFICIENT_BALANCE)
            (try! (stx-transfer? payment tx-sender (as-contract tx-sender)))
            (map-set subscriptions subscription-id (merge subscription {
                balance: (+ (get balance subscription) payment),
                expires-at: (+ (get expires-at subscription) u4320)
            }))
            (ok true)
        )
    )
)

(define-read-only (get-subscription (subscription-id uint))
    (map-get? subscriptions subscription-id)
)

(define-read-only (is-subscription-active (subscription-id uint))
    (match (map-get? subscriptions subscription-id)
        subscription (< stacks-block-height (get expires-at subscription))
        false
    )
)


(define-map insurance-policies uint {
    buyer: principal,
    data-id: uint,
    premium-paid: uint,
    coverage-amount: uint,
    expires-at: uint,
    claim-processed: bool
})

(define-map insurance-claims uint {
    policy-id: uint,
    claimed-at: uint,
    claim-amount: uint,
    approved: bool
})

(define-public (purchase-data-with-insurance (data-id uint))
    (begin
        (asserts! (is-some (map-get? sensor-data data-id)) ERR_DATA_NOT_FOUND)
        (asserts! (not (get sold (unwrap-panic (map-get? sensor-data data-id)))) ERR_DATA_NOT_FOUND)
        (let ((data-price (get price (unwrap-panic (map-get? sensor-data data-id))))
              (farmer-rep (get-farmer-reputation (get farmer (unwrap-panic (map-get? sensor-data data-id)))))
              (premium-rate (if (>= farmer-rep u10) u5 u10)))
            (let ((insurance-premium (/ (* data-price premium-rate) u100))
                  (total-cost (+ data-price insurance-premium))
                  (policy-id (var-get next-policy-id)))
                (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
                (try! (as-contract (stx-transfer? 
                    (/ (* data-price u80) u100) 
                    tx-sender 
                    (get farmer (unwrap-panic (map-get? sensor-data data-id)))
                )))
                (var-set treasury-balance (+ (var-get treasury-balance) 
                    (/ (* data-price u20) u100)
                ))
                (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) insurance-premium))
                (map-set insurance-policies policy-id {
                    buyer: tx-sender,
                    data-id: data-id,
                    premium-paid: insurance-premium,
                    coverage-amount: data-price,
                    expires-at: (+ stacks-block-height u2160),
                    claim-processed: false
                })
                (map-set sensor-data data-id (merge 
                    (unwrap-panic (map-get? sensor-data data-id))
                    {sold: true, buyer: (some tx-sender)}
                ))
                (var-set next-policy-id (+ policy-id u1))
                (ok policy-id)
            )
        )
    )
)

(define-public (claim-insurance (policy-id uint))
    (begin
        (asserts! (is-some (map-get? insurance-policies policy-id)) ERR_INSURANCE_NOT_FOUND)
        (let ((policy (unwrap-panic (map-get? insurance-policies policy-id))))
            (asserts! (is-eq tx-sender (get buyer policy)) ERR_NOT_AUTHORIZED)
            (asserts! (< stacks-block-height (get expires-at policy)) ERR_INSURANCE_EXPIRED)
            (asserts! (not (get claim-processed policy)) ERR_CLAIM_ALREADY_PROCESSED)
            (asserts! (>= (var-get insurance-pool-balance) (get coverage-amount policy)) ERR_INSUFFICIENT_INSURANCE_BALANCE)
            (try! (as-contract (stx-transfer? 
                (get coverage-amount policy) 
                tx-sender 
                (get buyer policy)
            )))
            (var-set insurance-pool-balance (- (var-get insurance-pool-balance) (get coverage-amount policy)))
            (map-set insurance-policies policy-id (merge policy {claim-processed: true}))
            (ok true)
        )
    )
)

(define-read-only (get-insurance-policy (policy-id uint))
    (map-get? insurance-policies policy-id)
)

(define-read-only (get-insurance-pool-balance)
    (var-get insurance-pool-balance)
)