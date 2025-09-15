;; Smart Contract Implementation
;; Advanced blockchain contract with comprehensive functionality

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var total-operations uint u0)
(define-data-var fee-rate uint u100) ;; 1% = 100 basis points

;; Data Maps
(define-map authorized-users principal bool)
(define-map user-balances principal uint)
(define-map operation-history uint {
    user: principal,
    operation-type: (string-ascii 50),
    amount: uint,
    timestamp: uint,
    status: (string-ascii 20)
})

(define-map user-profiles principal {
    id: uint,
    status: (string-ascii 20),
    reputation-score: uint,
    total-transactions: uint,
    created-at: uint,
    last-active: uint
})

;; Non-Fungible Token for certificates/credentials
(define-non-fungible-token platform-certificate uint)
(define-data-var last-certificate-id uint u0)

;; Fungible Token for platform utility
(define-fungible-token platform-token)
(define-data-var token-supply uint u1000000000000) ;; 1M tokens with 6 decimals

;; Authorization Functions
(define-private (is-authorized (user principal))
    (or (is-eq user CONTRACT_OWNER)
        (default-to false (map-get? authorized-users user))))

(define-private (is-contract-active)
    (var-get contract-active))

;; Admin Functions
(define-public (set-authorized-user (user principal) (authorized bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set authorized-users user authorized))))

(define-public (toggle-contract (active bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (var-set contract-active active))))

(define-public (update-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-rate u1000) ERR_INVALID_INPUT) ;; Max 10%
        (ok (var-set fee-rate new-rate))))

;; Core Business Logic Functions
(define-public (register-user (user-id uint))
    (let ((existing-profile (map-get? user-profiles tx-sender)))
        (begin
            (asserts! (is-contract-active) ERR_UNAUTHORIZED)
            (asserts! (is-none existing-profile) ERR_ALREADY_EXISTS)
            (map-set user-profiles tx-sender {
                id: user-id,
                status: "active",
                reputation-score: u100,
                total-transactions: u0,
                created-at: block-height,
                last-active: block-height
            })
            (map-set user-balances tx-sender u0)
            (ok user-id))))

(define-public (execute-operation (operation-type (string-ascii 50)) (amount uint))
    (let (
        (user-profile (unwrap! (map-get? user-profiles tx-sender) ERR_NOT_FOUND))
        (current-balance (default-to u0 (map-get? user-balances tx-sender)))
        (operation-id (+ (var-get total-operations) u1))
        (fee (/ (* amount (var-get fee-rate)) u10000))
        (net-amount (- amount fee))
    )
    (begin
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_INPUT)
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
        
        ;; Record operation
        (map-set operation-history operation-id {
            user: tx-sender,
            operation-type: operation-type,
            amount: amount,
            timestamp: block-height,
            status: "completed"
        })
        
        ;; Update user balance
        (map-set user-balances tx-sender (- current-balance amount))
        
        ;; Update user profile
        (map-set user-profiles tx-sender (merge user-profile {
            total-transactions: (+ (get total-transactions user-profile) u1),
            last-active: block-height
        }))
        
        ;; Update contract state
        (var-set total-operations operation-id)
        
        (ok operation-id))))

(define-public (deposit-funds (amount uint))
    (let ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
        (begin
            (asserts! (is-contract-active) ERR_UNAUTHORIZED)
            (asserts! (> amount u0) ERR_INVALID_INPUT)
            
            ;; In a real implementation, this would handle STX transfer
            ;; For now, we just update the balance mapping
            (map-set user-balances tx-sender (+ current-balance amount))
            (ok (+ current-balance amount)))))

(define-public (withdraw-funds (amount uint))
    (let ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
        (begin
            (asserts! (is-contract-active) ERR_UNAUTHORIZED)
            (asserts! (> amount u0) ERR_INVALID_INPUT)
            (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
            
            (map-set user-balances tx-sender (- current-balance amount))
            ;; In a real implementation, this would transfer STX to user
            (ok (- current-balance amount)))))

(define-public (mint-certificate (recipient principal) (metadata (string-ascii 200)))
    (let ((certificate-id (+ (var-get last-certificate-id) u1)))
        (begin
            (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
            (asserts! (is-contract-active) ERR_UNAUTHORIZED)
            
            (unwrap! (nft-mint? platform-certificate certificate-id recipient) ERR_INVALID_INPUT)
            (var-set last-certificate-id certificate-id)
            
            (ok certificate-id))))

(define-public (transfer-certificate (certificate-id uint) (recipient principal))
    (begin
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (unwrap! (nft-transfer? platform-certificate certificate-id tx-sender recipient) ERR_UNAUTHORIZED)
        (ok certificate-id)))

;; Platform Token Functions
(define-public (mint-tokens (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (unwrap! (ft-mint? platform-token amount recipient) ERR_INVALID_INPUT)
        (ok amount)))

(define-public (transfer-tokens (amount uint) (recipient principal))
    (begin
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (unwrap! (ft-transfer? platform-token amount tx-sender recipient) ERR_INVALID_INPUT)
        (ok amount)))

;; Read-Only Functions
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user))

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user)))

(define-read-only (get-operation (operation-id uint))
    (map-get? operation-history operation-id))

(define-read-only (get-contract-info)
    {
        active: (var-get contract-active),
        total-operations: (var-get total-operations),
        fee-rate: (var-get fee-rate),
        owner: CONTRACT_OWNER
    })

(define-read-only (get-certificate-owner (certificate-id uint))
    (nft-get-owner? platform-certificate certificate-id))

(define-read-only (get-token-balance (user principal))
    (ft-get-balance platform-token user))

(define-read-only (get-total-token-supply)
    (ft-get-supply platform-token))

;; Utility Functions
(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get fee-rate)) u10000))

(define-private (update-reputation (user principal) (score-delta int))
    (let ((user-profile (unwrap! (map-get? user-profiles user) ERR_NOT_FOUND)))
        (let ((current-score (get reputation-score user-profile)))
            (let ((new-score (if (> score-delta 0)
                                (+ current-score (to-uint score-delta))
                                (if (>= current-score (to-uint (- score-delta)))
                                    (- current-score (to-uint (- score-delta)))
                                    u0))))
                (map-set user-profiles user (merge user-profile {
                    reputation-score: new-score
                }))
                (ok new-score)))))

;; Event Logging (using print statements for now)
(define-private (log-event (event-type (string-ascii 50)) (details (string-ascii 200)))
    (begin
        (print {event: event-type, details: details, user: tx-sender, block: block-height})
        true))

;; Initialization
(begin
    (map-set authorized-users CONTRACT_OWNER true)
    (log-event "contract-deployed" "Smart contract successfully deployed"))
