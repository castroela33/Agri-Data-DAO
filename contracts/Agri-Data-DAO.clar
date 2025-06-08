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
