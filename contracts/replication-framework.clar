;; Replication Framework Contract
;; Facilitates regenerative social system scaling

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_TEMPLATE_NOT_FOUND (err u501))
(define-constant ERR_INVALID_PARAMETERS (err u502))
(define-constant ERR_REPLICATION_FAILED (err u503))

;; System templates for replication
(define-map system-templates
  { template-id: uint }
  {
    name: (string-ascii 50),
    creator: principal,
    source-community: uint,
    success-rate: uint,
    replication-count: uint,
    complexity-level: uint,
    created-at: uint
  }
)

;; Template components and configurations
(define-map template-configs
  { template-id: uint }
  {
    governance-model: (string-ascii 30),
    resource-allocation: uint,
    community-size-min: uint,
    community-size-max: uint,
    required-skills: uint,
    adaptation-flexibility: uint
  }
)

;; Replication instances
(define-map replications
  { replication-id: uint }
  {
    template-id: uint,
    target-community: uint,
    replicator: principal,
    status: uint,
    adaptation-level: uint,
    success-metrics: uint,
    started-at: uint
  }
)

;; Replication status constants
(define-constant STATUS_INITIATED u1)
(define-constant STATUS_ADAPTING u2)
(define-constant STATUS_IMPLEMENTING u3)
(define-constant STATUS_TESTING u4)
(define-constant STATUS_COMPLETED u5)
(define-constant STATUS_FAILED u6)

;; Create system template
(define-public (create-template (name (string-ascii 50)) (source-community uint) (complexity uint))
  (let ((template-id (+ (var-get next-template-id) u1)))
    (asserts! (and (> complexity u0) (<= complexity u10)) ERR_INVALID_PARAMETERS)

    (map-set system-templates
      { template-id: template-id }
      {
        name: name,
        creator: tx-sender,
        source-community: source-community,
        success-rate: u0,
        replication-count: u0,
        complexity-level: complexity,
        created-at: block-height
      }
    )

    (var-set next-template-id template-id)
    (ok template-id)
  )
)

;; Configure template parameters
(define-public (configure-template (template-id uint) (governance (string-ascii 30)) (resources uint) (min-size uint) (max-size uint) (skills uint) (flexibility uint))
  (let ((template (unwrap! (map-get? system-templates { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND)))
    (asserts! (is-eq (get creator template) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (and (> min-size u0) (> max-size min-size)) ERR_INVALID_PARAMETERS)
    (asserts! (and (<= skills u100) (<= flexibility u100)) ERR_INVALID_PARAMETERS)

    (map-set template-configs
      { template-id: template-id }
      {
        governance-model: governance,
        resource-allocation: resources,
        community-size-min: min-size,
        community-size-max: max-size,
        required-skills: skills,
        adaptation-flexibility: flexibility
      }
    )
    (ok true)
  )
)

;; Initiate replication
(define-public (initiate-replication (template-id uint) (target-community uint) (adaptation-level uint))
  (let (
    (template (unwrap! (map-get? system-templates { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND))
    (config (unwrap! (map-get? template-configs { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND))
    (replication-id (+ (var-get next-replication-id) u1))
  )
    (asserts! (<= adaptation-level (get adaptation-flexibility config)) ERR_INVALID_PARAMETERS)

    (map-set replications
      { replication-id: replication-id }
      {
        template-id: template-id,
        target-community: target-community,
        replicator: tx-sender,
        status: STATUS_INITIATED,
        adaptation-level: adaptation-level,
        success-metrics: u0,
        started-at: block-height
      }
    )

    (var-set next-replication-id replication-id)
    (ok replication-id)
  )
)

;; Update replication status
(define-public (update-replication-status (replication-id uint) (new-status uint))
  (let ((replication (unwrap! (map-get? replications { replication-id: replication-id }) ERR_TEMPLATE_NOT_FOUND)))
    (asserts! (is-eq (get replicator replication) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (and (>= new-status STATUS_INITIATED) (<= new-status STATUS_FAILED)) ERR_INVALID_PARAMETERS)

    (map-set replications
      { replication-id: replication-id }
      (merge replication { status: new-status })
    )

    ;; Update template success rate if replication completed
    (if (is-eq new-status STATUS_COMPLETED)
      (update-template-success-rate (get template-id replication))
      (ok true)
    )
  )
)

;; Update template success rate
(define-private (update-template-success-rate (template-id uint))
  (let ((template (unwrap! (map-get? system-templates { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND)))
    (map-set system-templates
      { template-id: template-id }
      (merge template {
        replication-count: (+ (get replication-count template) u1),
        success-rate: (calculate-success-rate template-id)
      })
    )
    (ok true)
  )
)

;; Calculate template success rate
(define-private (calculate-success-rate (template-id uint))
  ;; Simplified calculation - in practice would iterate through all replications
  u75  ;; Placeholder return value
)

;; Record replication success metrics
(define-public (record-success-metrics (replication-id uint) (metrics uint))
  (let ((replication (unwrap! (map-get? replications { replication-id: replication-id }) ERR_TEMPLATE_NOT_FOUND)))
    (asserts! (is-eq (get replicator replication) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= metrics u100) ERR_INVALID_PARAMETERS)

    (map-set replications
      { replication-id: replication-id }
      (merge replication { success-metrics: metrics })
    )
    (ok true)
  )
)

;; Get template info
(define-read-only (get-template (template-id uint))
  (map-get? system-templates { template-id: template-id })
)

;; Get template configuration
(define-read-only (get-template-config (template-id uint))
  (map-get? template-configs { template-id: template-id })
)

;; Get replication info
(define-read-only (get-replication (replication-id uint))
  (map-get? replications { replication-id: replication-id })
)

;; Check replication compatibility
(define-read-only (check-compatibility (template-id uint) (community-size uint) (available-skills uint))
  (match (map-get? template-configs { template-id: template-id })
    config (and (>= community-size (get community-size-min config))
                (<= community-size (get community-size-max config))
                (>= available-skills (get required-skills config)))
    false
  )
)

(define-data-var next-template-id uint u0)
(define-data-var next-replication-id uint u0)
