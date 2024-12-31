;; Stacks Name Service (SNS)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_NAME_TAKEN (err u2))
(define-constant ERR_NAME_NOT_FOUND (err u3))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u4))
(define-constant ERR_NAME_LOCKED (err u5))
(define-constant REGISTRATION_COST_STX u1000000) ;; 1 STX
(define-constant REGISTRATION_DURATION u31536000) ;; 1 year in seconds
(define-constant GRACE_PERIOD u2592000) ;; 30 days in seconds

;; Data Maps
(define-map names
  { name: (string-ascii 256) }
  {
    owner: principal,
    expires-at: uint,
    locked: bool,
    primary-address: (optional principal),
    records: (list 20 {key: (string-ascii 64), value: (string-utf8 256)})
  }
)

(define-map subdomains
  { parent: (string-ascii 256), name: (string-ascii 256) }
  { owner: principal }
)

(define-map name-offers
  { name: (string-ascii 256) }
  { price: uint, seller: principal }
)

;; Private Functions
(define-private (is-name-available (name (string-ascii 256)))
  (is-none (map-get? names {name: name}))
)

(define-private (is-name-owner (name (string-ascii 256)) (caller principal))
  (let ((entry (unwrap! (map-get? names {name: name}) false)))
    (is-eq (get owner entry) caller)
  )
)

(define-private (is-name-expired (name (string-ascii 256)))
  (let ((entry (unwrap! (map-get? names {name: name}) false)))
    (> block-height (+ (get expires-at entry) GRACE_PERIOD))
  )
)

;; Public Functions
(define-public (register-name (name (string-ascii 256)))
  (let ((caller tx-sender))
    (asserts! (is-name-available name) ERR_NAME_TAKEN)
    (try! (stx-transfer? REGISTRATION_COST_STX caller (as-contract tx-sender)))
    (ok (map-set names
      {name: name}
      {
        owner: caller,
        expires-at: (+ block-height REGISTRATION_DURATION),
        locked: false,
        primary-address: none,
        records: (list)
      }
    ))
  )
)

(define-public (renew-name (name (string-ascii 256)))
  (let (
    (caller tx-sender)
    (entry (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND))
  )
    (asserts! (or (is-name-owner name caller) (is-name-expired name)) ERR_UNAUTHORIZED)
    (try! (stx-transfer? REGISTRATION_COST_STX caller (as-contract tx-sender)))
    (ok (map-set names
      {name: name}
      (merge entry {
        owner: caller,
        expires-at: (+ block-height REGISTRATION_DURATION)
      })
    ))
  )
)

(define-public (set-name-owner (name (string-ascii 256)) (new-owner principal))
  (let ((caller tx-sender))
    (asserts! (is-name-owner name caller) ERR_UNAUTHORIZED)
    (ok (map-set names
      {name: name}
      (merge (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND)
        {owner: new-owner}
      )
    ))
  )
)

(define-public (set-primary-address (name (string-ascii 256)) (address (optional principal)))
  (let ((caller tx-sender))
    (asserts! (is-name-owner name caller) ERR_UNAUTHORIZED)
    (ok (map-set names
      {name: name}
      (merge (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND)
        {primary-address: address}
      )
    ))
  )
)

(define-public (add-record (name (string-ascii 256)) (key (string-ascii 64)) (value (string-utf8 256)))
  (let (
    (caller tx-sender)
    (entry (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND))
  )
    (asserts! (is-name-owner name caller) ERR_UNAUTHORIZED)
    (ok (map-set names
      {name: name}
      (merge entry {
        records: (unwrap! (as-max-len? (append (get records entry) {key: key, value: value}) u20) ERR_UNAUTHORIZED)
      })
    ))
  )
)

(define-public (register-subdomain (parent (string-ascii 256)) (subdomain (string-ascii 256)) (owner principal))
  (let ((caller tx-sender))
    (asserts! (is-name-owner parent caller) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? subdomains {parent: parent, name: subdomain})) ERR_NAME_TAKEN)
    (ok (map-set subdomains
      {parent: parent, name: subdomain}
      {owner: owner}
    ))
  )
)

(define-public (lock-name (name (string-ascii 256)))
  (let ((caller tx-sender))
    (asserts! (is-name-owner name caller) ERR_UNAUTHORIZED)
    (ok (map-set names
      {name: name}
      (merge (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND)
        {locked: true}
      )
    ))
  )
)

(define-public (unlock-name (name (string-ascii 256)))
  (let ((caller tx-sender))
    (asserts! (is-name-owner name caller) ERR_UNAUTHORIZED)
    (ok (map-set names
      {name: name}
      (merge (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND)
        {locked: false}
      )
    ))
  )
)

(define-public (create-name-offer (name (string-ascii 256)) (price uint))
  (let (
    (caller tx-sender)
    (entry (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND))
  )
    (asserts! (is-name-owner name caller) ERR_UNAUTHORIZED)
    (asserts! (not (get locked entry)) ERR_NAME_LOCKED)
    (ok (map-set name-offers
      {name: name}
      {price: price, seller: caller}
    ))
  )
)

(define-public (cancel-name-offer (name (string-ascii 256)))
  (let ((caller tx-sender))
    (asserts! (is-eq (get seller (unwrap! (map-get? name-offers {name: name}) ERR_NAME_NOT_FOUND)) caller) ERR_UNAUTHORIZED)
    (ok (map-delete name-offers {name: name}))
  )
)

(define-public (accept-name-offer (name (string-ascii 256)))
  (let (
    (caller tx-sender)
    (offer (unwrap! (map-get? name-offers {name: name}) ERR_NAME_NOT_FOUND))
    (entry (unwrap! (map-get? names {name: name}) ERR_NAME_NOT_FOUND))
  )
    (asserts! (not (get locked entry)) ERR_NAME_LOCKED)
    (try! (stx-transfer? (get price offer) caller (get seller offer)))
    (map-delete name-offers {name: name})
    (ok (map-set names
      {name: name}
      (merge entry {owner: caller})
    ))
  )
)

;; Read-only Functions
(define-read-only (get-name-info (name (string-ascii 256)))
  (map-get? names {name: name})
)

(define-read-only (get-subdomain-owner (parent (string-ascii 256)) (subdomain (string-ascii 256)))
  (match (map-get? subdomains {parent: parent, name: subdomain}) 
    subdomain-entry 
    (some (get owner subdomain-entry)) 
    none)
)

(define-read-only (get-name-offer (name (string-ascii 256)))
  (map-get? name-offers {name: name})
)

(define-read-only (resolve-name (name (string-ascii 256)))
  (match (map-get? names {name: name})
    entry 
    (get primary-address entry)
    none)
)