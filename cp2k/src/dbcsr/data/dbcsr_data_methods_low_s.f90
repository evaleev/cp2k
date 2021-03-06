!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2017  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Sets a data pointer.
!> \param[inout] area     target data area
!> \param[in]    p        source data pointer
!> \par Assumptions
!>      Assumes that no memory will be lost when repointing the
!>      pointer in the data area and that the area is initialized.
! **************************************************************************************************
  SUBROUTINE set_data_p_s (area, p)
    TYPE(dbcsr_data_obj), INTENT(INOUT)      :: area
    REAL(kind=real_4), DIMENSION(:), POINTER :: p

    CHARACTER(len=*), PARAMETER :: routineN = 'set_data_p_s', &
      routineP = moduleN//':'//routineN

!   ---------------------------------------------------------------------------
    IF(area%d%data_type /= dbcsr_type_real_4) &
       CPABORT("set_data_p_s: data-area has wrong type")

    area%d%r_sp => p
  END SUBROUTINE set_data_p_s

! **************************************************************************************************
!> \brief Sets a data pointer.
!> \param[inout] area     target data area
!> \param[in]    p        source data pointer
!> \par Assumptions
!>      Assumes that no memory will be lost when repointing the
!>      pointer in the data area and that the area is initialized.
! **************************************************************************************************
  SUBROUTINE set_data_p_2d_s (area, p)
    TYPE(dbcsr_data_obj), INTENT(INOUT)      :: area
    REAL(kind=real_4), DIMENSION(:,:), POINTER         :: p

    CHARACTER(len=*), PARAMETER :: routineN = 'set_data_p_2d_s', &
      routineP = moduleN//':'//routineN

!   ---------------------------------------------------------------------------

    IF(area%d%data_type /= dbcsr_type_real_4_2d) &
       CPABORT("set_data_p_2d_s: data-area has wrong type")

    area%d%r2_sp => p
  END SUBROUTINE set_data_p_2d_s


! **************************************************************************************************
!> \brief Returns the single/double precision real/complex data
!> \param[in] area       data area
!> \param[in] select_data_type   force datatype
!> \param[in] lb         (optional) lower bound for pointer
!> \param[in] ub         (optional) upper bound for pointer
!> \retval data          pointer to data
!> \par Calling
!>      This routine is hidden behind the dbcsr_get_data interface, hence the
!>      need for the select_data_type argument.
!>      see dbcsr_get_data_p_s
! **************************************************************************************************
  FUNCTION dbcsr_get_data_c_s (area, select_data_type, lb, ub) RESULT (DATA)
    TYPE(dbcsr_data_obj), INTENT(IN)         :: area
    REAL(kind=real_4), INTENT(IN)            :: select_data_type
    INTEGER, INTENT(IN), OPTIONAL  :: lb, ub
    REAL(kind=real_4), DIMENSION(:), POINTER :: DATA

    CHARACTER(len=*), PARAMETER :: routineN = 'dbcsr_get_data_c_s', &
      routineP = moduleN//':'//routineN

    INTEGER                        :: l, u

!   ---------------------------------------------------------------------------

    ! The select_data_type argument is needed to make this function unique
    ! enough to use in the interface.
    IF (KIND(select_data_type) .NE. KIND(DATA))&
       CPABORT("compiler borken")

    IF (ASSOCIATED (area%d)) THEN
       IF(area%d%data_type /= dbcsr_type_real_4) &
          CPABORT("dbcsr_get_data_c_s: data-area has wrong type")
       IF (PRESENT (lb) .OR. PRESENT (ub)) THEN
          l = LBOUND (area%d%r_sp, 1)
          IF (PRESENT (lb)) l = lb
          u = UBOUND (area%d%r_sp, 1)
          IF (PRESENT (ub)) u = ub
          IF (debug_mod) THEN
             IF(l .LT. LBOUND (area%d%r_sp, 1))&
                CPABORT("Out of bounds")
             IF(u .GT. UBOUND (area%d%r_sp, 1))&
                CPABORT("Out of bounds")
          ENDIF
          DATA => area%d%r_sp(l:u)
       ELSE
          DATA => area%d%r_sp
       ENDIF
    ELSE
       NULLIFY (DATA)
    ENDIF
  END FUNCTION dbcsr_get_data_c_s

! **************************************************************************************************
!> \brief Returns the single/double precision real/complex data
!> \brief dbcsr_get_data_c_s
!> \param[in] area       data area
!> \param[in] lb         (optional) lower bound for pointer
!> \param[in] ub         (optional) upper bound for pointer
!> \retval DATA pointer to data
!> \par Calling
!>      This routine can be called explicitly.
! **************************************************************************************************
  FUNCTION dbcsr_get_data_p_s (area, lb, ub) RESULT (DATA)
    TYPE(dbcsr_data_obj), INTENT(IN)         :: area
    REAL(kind=real_4), DIMENSION(:), POINTER :: DATA
    INTEGER, INTENT(IN), OPTIONAL  :: lb, ub

    CHARACTER(len=*), PARAMETER :: routineN = 'dbcsr_get_data_p_s', &
      routineP = moduleN//':'//routineN

    INTEGER                        :: l, u
!   ---------------------------------------------------------------------------

    IF (ASSOCIATED (area%d)) THEN
       IF(area%d%data_type /= dbcsr_type_real_4) &
          CPABORT("dbcsr_get_data_p_s: data-area has wrong type")
       IF (PRESENT (lb) .OR. PRESENT (ub)) THEN
          l = LBOUND (area%d%r_sp, 1)
          IF (PRESENT (lb)) l = lb
          u = UBOUND (area%d%r_sp, 1)
          IF (PRESENT (ub)) u = ub
          IF (debug_mod) THEN
             IF(l .LT. LBOUND (area%d%r_sp, 1))&
                CPABORT("Out of bounds")
             IF(u .GT. UBOUND (area%d%r_sp, 1))&
                CPABORT("Out of bounds")
          ENDIF
          DATA => area%d%r_sp(l:u)
       ELSE
          DATA => area%d%r_sp
       ENDIF
    ELSE
       NULLIFY (DATA)
    ENDIF
  END FUNCTION dbcsr_get_data_p_s

! **************************************************************************************************
!> \brief Returns the single/double precision real/complex data
!> \brief dbcsr_get_data_c_s
!> \param[in] area       data area
!> \param[in] lb         (optional) lower bound for pointer
!> \param[in] ub         (optional) upper bound for pointer
!> \retval DATA pointer to data
!> \par Calling
!>      This routine can be called explicitly.
! **************************************************************************************************
  FUNCTION dbcsr_get_data_p_2d_s (area, lb, ub) RESULT (DATA)
    TYPE(dbcsr_data_obj), INTENT(IN)            :: area
    REAL(kind=real_4), DIMENSION(:,:), POINTER            :: DATA
    INTEGER, DIMENSION(2), INTENT(IN), OPTIONAL :: lb, ub

    CHARACTER(len=*), PARAMETER :: routineN = 'dbcsr_get_data_p_2d_s', &
      routineP = moduleN//':'//routineN

    INTEGER, DIMENSION(2)          :: l, u
!   ---------------------------------------------------------------------------

    IF (ASSOCIATED (area%d)) THEN
       IF(area%d%data_type /= dbcsr_type_real_4_2d) &
          CPABORT("dbcsr_get_data_p_2d_s: data-area has wrong type")
       IF (PRESENT (lb) .OR. PRESENT (ub)) THEN
          l = LBOUND (area%d%r2_sp)
          IF (PRESENT (lb)) l = lb
          u = UBOUND (area%d%r2_sp)
          IF (PRESENT (ub)) u = ub
          IF (debug_mod) THEN
             IF(l(1) .LT. LBOUND (area%d%r2_sp, 1))&
                CPABORT("Out of bounds")
             IF(l(2) .LT. LBOUND (area%d%r2_sp, 2))&
                CPABORT("Out of bounds")
             IF(u(1) .GT. UBOUND (area%d%r2_sp, 1))&
                CPABORT("Out of bounds")
             IF(u(2) .GT. UBOUND (area%d%r2_sp, 2))&
                CPABORT("Out of bounds")
          ENDIF
          DATA => area%d%r2_sp(l(1):u(1), l(2):u(2))
       ELSE
          DATA => area%d%r2_sp
       ENDIF
    ELSE
       NULLIFY (DATA)
    ENDIF
  END FUNCTION dbcsr_get_data_p_2d_s



! **************************************************************************************************
!> \brief Returns the single/double precision real/complex data
!> \param[in] area       data area
!> \param[out] DATA pointer to data
!> \param[in] lb         (optional) lower bound for pointer
!> \param[in] ub         (optional) upper bound for pointer
! **************************************************************************************************
  SUBROUTINE get_data_s (area, DATA, lb, ub)
    TYPE(dbcsr_data_obj), INTENT(IN)  :: area
    REAL(kind=real_4), DIMENSION(:), POINTER    :: DATA
    INTEGER, INTENT(IN), OPTIONAL     :: lb, ub

    CHARACTER(len=*), PARAMETER :: routineN = 'get_data_s', &
      routineP = moduleN//':'//routineN

    INTEGER                        :: l, u
!   ---------------------------------------------------------------------------

    IF (ASSOCIATED (area%d)) THEN
       IF(area%d%data_type /= dbcsr_type_real_4) &
          CPABORT("get_data_s: data-area has wrong type")
       IF (PRESENT (lb) .OR. PRESENT (ub)) THEN
          l = LBOUND (area%d%r_sp, 1)
          IF (PRESENT (lb)) l = lb
          u = UBOUND (area%d%r_sp, 1)
          IF (PRESENT (ub)) u = ub
          IF (debug_mod) THEN
             IF(l < LBOUND (area%d%r_sp, 1)) &
                CPABORT("Out of bounds")
             IF(u > UBOUND (area%d%r_sp, 1)) &
                CPABORT("Out of bounds")
          ENDIF
          DATA => area%d%r_sp(l:u)
       ELSE
          DATA => area%d%r_sp
       ENDIF
    ELSE
       NULLIFY (DATA)
    ENDIF
  END SUBROUTINE get_data_s


! **************************************************************************************************
!> \brief Returns the single/double precision real/complex data
!> \param[in] area       data area
!> \param[out] DATA pointer to data
!> \param[in] lb         (optional) lower bound for pointer
!> \param[in] ub         (optional) upper bound for pointer
! **************************************************************************************************
  SUBROUTINE get_data_2d_s (area, DATA, lb, ub)
    TYPE(dbcsr_data_obj), INTENT(IN)            :: area
    REAL(kind=real_4), DIMENSION(:,:), POINTER            :: DATA
    INTEGER, DIMENSION(2), INTENT(IN), OPTIONAL :: lb, ub

    CHARACTER(len=*), PARAMETER :: routineN = 'get_data_2d_s', &
      routineP = moduleN//':'//routineN

    INTEGER, DIMENSION(2)          :: l, u
!   ---------------------------------------------------------------------------

    IF (ASSOCIATED (area%d)) THEN
       IF(area%d%data_type /= dbcsr_type_real_4_2d) &
          CPABORT("get_data_2d_s: data-area has wrong type")
       IF (PRESENT (lb) .OR. PRESENT (ub)) THEN
          l = LBOUND (area%d%r2_sp)
          IF (PRESENT (lb)) l = lb
          u = UBOUND (area%d%r2_sp)
          IF (PRESENT (ub)) u = ub
          IF (debug_mod) THEN
             IF(l(1) < LBOUND (area%d%r2_sp, 1)) &
                CPABORT("Out of bounds")
             IF(l(2) < LBOUND (area%d%r2_sp, 2)) &
                CPABORT("Out of bounds")
             IF(u(1) > UBOUND (area%d%r2_sp, 1)) &
                CPABORT("Out of bounds")
             IF(u(2) > UBOUND (area%d%r2_sp, 2)) &
                CPABORT("Out of bounds")
          ENDIF
          DATA => area%d%r2_sp(l(1):u(1), l(2):u(2))
       ELSE
          DATA => area%d%r2_sp
       ENDIF
    ELSE
       NULLIFY (DATA)
    ENDIF
  END SUBROUTINE get_data_2d_s

! **************************************************************************************************
!> \brief Sets a scalar in an encapsulated data structure
!> \param[in] scalar                    scalar to encapsulate
!> \retval encapsulated_scalar          encapsulated scalar 
! **************************************************************************************************
  ELEMENTAL FUNCTION dbcsr_scalar_s (scalar) RESULT (encapsulated_scalar)
    REAL(kind=real_4), INTENT(IN)       :: scalar
    TYPE(dbcsr_scalar_type)   :: encapsulated_scalar

    CHARACTER(len=*), PARAMETER :: routineN = 'dbcsr_scalar_s', &
      routineP = moduleN//':'//routineN

!   ---------------------------------------------------------------------------

    encapsulated_scalar = dbcsr_scalar_zero (dbcsr_type_real_4)
    encapsulated_scalar%r_sp = scalar
  END FUNCTION dbcsr_scalar_s

! **************************************************************************************************
!> \brief Sets a scalar in an encapsulated data structure
!> \param[in] encapsulated_scalar          encapsulated scalar
!> \param[out] value                       value of the scalar
! **************************************************************************************************
  ELEMENTAL SUBROUTINE dbcsr_scalar_get_value_s (encapsulated_scalar, value)
    TYPE(dbcsr_scalar_type), INTENT(IN) :: encapsulated_scalar
    REAL(kind=real_4), INTENT(OUT)                :: value

    CHARACTER(len=*), PARAMETER :: routineN = 'dbcsr_scalar_get_value_s', &
      routineP = moduleN//':'//routineN

!   ---------------------------------------------------------------------------

    value = encapsulated_scalar%r_sp
  END SUBROUTINE dbcsr_scalar_get_value_s
