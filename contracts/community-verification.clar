;; Community Verification Contract
;; Validates regenerative social communities

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_COMMUNITY_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))
(define-constant ERR_INVALID_METRICS (err u103))

;; Community data structure
(define-map communities
  { community-id: uint }
  {
    name: (string-ascii 50),
    creator: principal,
    members-count: uint,
    sustainability-score: uint,
    verified: bool,
    created-at: uint
  }
)

;; Community verification requirements
(define-map verification-requirements
  { community-id: uint }
  {
    min-members: uint,
    min-sustainability-score: uint,
    required-activities: uint
  }
)

;; Track community activities
(define-map community-activities
  { community-id: uint }
  {
    regenerative-projects: uint,
    resource-sharing-events: uint,
    educational-programs: uint,
    environmental-initiatives: uint
  }
)

;; Register a new community
(define-public (register-community (name (string-ascii 50)) (min-members uint) (min-sustainability uint))
  (let ((community-id (+ (var-get next-community-id) u1)))
    (map-set communities
      { community-id: community-id }
      {
        name: name,
        creator: tx-sender,
        members-count: u0,
        sustainability-score: u0,
        verified: false,
        created-at: block-height
      }
    )
    (map-set verification-requirements
      { community-id: community-id }
      {
        min-members: min-members,
        min-sustainability-score: min-sustainability,
        required-activities: u5
      }
    )
    (var-set next-community-id community-id)
    (ok community-id)
  )
)

;; Update community metrics
(define-public (update-community-metrics (community-id uint) (members uint) (sustainability uint))
  (let ((community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND)))
    (asserts! (is-eq (get creator community) tx-sender) ERR_UNAUTHORIZED)
    (map-set communities
      { community-id: community-id }
      (merge community {
        members-count: members,
        sustainability-score: sustainability
      })
    )
    (ok true)
  )
)

;; Record community activities
(define-public (record-activities (community-id uint) (projects uint) (sharing uint) (education uint) (environment uint))
  (let ((community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND)))
    (asserts! (is-eq (get creator community) tx-sender) ERR_UNAUTHORIZED)
    (map-set community-activities
      { community-id: community-id }
      {
        regenerative-projects: projects,
        resource-sharing-events: sharing,
        educational-programs: education,
        environmental-initiatives: environment
      }
    )
    (ok true)
  )
)

;; Verify community based on requirements
(define-public (verify-community (community-id uint))
  (let (
    (community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND))
    (requirements (unwrap! (map-get? verification-requirements { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND))
    (activities (default-to { regenerative-projects: u0, resource-sharing-events: u0, educational-programs: u0, environmental-initiatives: u0 }
                 (map-get? community-activities { community-id: community-id })))
  )
    (asserts! (not (get verified community)) ERR_ALREADY_VERIFIED)
    (asserts! (>= (get members-count community) (get min-members requirements)) ERR_INVALID_METRICS)
    (asserts! (>= (get sustainability-score community) (get min-sustainability-score requirements)) ERR_INVALID_METRICS)
    (asserts! (>= (+ (get regenerative-projects activities) (get resource-sharing-events activities)
                     (get educational-programs activities) (get environmental-initiatives activities))
                  (get required-activities requirements)) ERR_INVALID_METRICS)

    (map-set communities
      { community-id: community-id }
      (merge community { verified: true })
    )
    (ok true)
  )
)

;; Get community info
(define-read-only (get-community (community-id uint))
  (map-get? communities { community-id: community-id })
)

;; Get community activities
(define-read-only (get-community-activities (community-id uint))
  (map-get? community-activities { community-id: community-id })
)

;; Check if community is verified
(define-read-only (is-community-verified (community-id uint))
  (match (map-get? communities { community-id: community-id })
    community (get verified community)
    false
  )
)

(define-data-var next-community-id uint u0)
