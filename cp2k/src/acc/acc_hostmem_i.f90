!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2017  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!


! **************************************************************************************************
!> \brief Allocates 1D fortan-array as cuda host-pinned memory.
!> \param host_mem pointer to array
!> \param n size given in terms of item-count (not bytes!)
!> \param stream ...
!> \author  Ole Schuett
! **************************************************************************************************
  SUBROUTINE acc_hostmem_alloc_i (host_mem, n, stream)
    INTEGER(KIND=int_4), DIMENSION(:), POINTER           :: host_mem
    INTEGER, INTENT(IN)                      :: n
    TYPE(acc_stream_type), INTENT(IN)        :: stream
#if defined (__ACC)
    TYPE(C_PTR)                              :: host_mem_c_ptr

    CALL acc_hostmem_alloc_raw(host_mem_c_ptr, MAX(1,n)*int_4_size, stream)
    CALL C_F_POINTER (host_mem_c_ptr, host_mem, (/ MAX(1,n) /))
#else
    MARK_USED(host_mem)
    MARK_USED(n)
    MARK_USED(stream)
    CPABORT("acc_hostmem_alloc_i: ACC not compiled in.")
#endif
  END SUBROUTINE acc_hostmem_alloc_i



! **************************************************************************************************
!> \brief Allocates 2D fortan-array as cuda host-pinned memory.
!> \param host_mem pointer to array
!> \param n1 sizes given in terms of item-count (not bytes!)
!> \param n2 sizes given in terms of item-count (not bytes!)
!> \param stream ...
!> \author  Ole Schuett
! **************************************************************************************************
  SUBROUTINE acc_hostmem_alloc_i_2D (host_mem, n1, n2, stream)
    INTEGER(KIND=int_4), DIMENSION(:,:), POINTER           :: host_mem
    INTEGER, INTENT(IN)                      :: n1, n2
    TYPE(acc_stream_type), INTENT(IN)        :: stream
#if defined (__ACC)
    TYPE(C_PTR)                              :: host_mem_c_ptr
    INTEGER                                  :: n_bytes

    n_bytes = MAX(1,n1)*MAX(1,n2)*int_4_size
    CALL acc_hostmem_alloc_raw(host_mem_c_ptr, n_bytes, stream)
    CALL C_F_POINTER (host_mem_c_ptr, host_mem, (/ MAX(1,n1),MAX(1,n2) /))
#else
    MARK_USED(host_mem)
    MARK_USED(n1)
    MARK_USED(n2)
    MARK_USED(stream)
    CPABORT("acc_hostmem_alloc_i_2D: ACC not compiled in.")
#endif
  END SUBROUTINE acc_hostmem_alloc_i_2D


! **************************************************************************************************
!> \brief Deallocates a 1D fortan-array, which is cuda host-pinned memory.
!> \param host_mem pointer to array
!> \param stream ...
!> \author  Ole Schuett
! **************************************************************************************************
  SUBROUTINE acc_hostmem_dealloc_i (host_mem, stream)
    INTEGER(KIND=int_4), DIMENSION(:), &
      POINTER                                :: host_mem
    TYPE(acc_stream_type), INTENT(IN)        :: stream
    CHARACTER(len=*), PARAMETER :: routineN = 'acc_hostmem_dealloc_i', &
      routineP = moduleN//':'//routineN

    IF (SIZE (host_mem) == 0) RETURN
#if defined (__ACC)
    CALL acc_hostmem_dealloc_raw(C_LOC(host_mem(1)), stream)
#else
    MARK_USED(host_mem)
    MARK_USED(stream)
    CPABORT("acc_hostmem_dealloc_i: ACC not compiled in.")
#endif
  END SUBROUTINE acc_hostmem_dealloc_i


! **************************************************************************************************
!> \brief Deallocates a 2D fortan-array, which is cuda host-pinned memory.
!> \param host_mem pointer to array
!> \param stream ...
!> \author  Ole Schuett
! **************************************************************************************************
  SUBROUTINE acc_hostmem_dealloc_i_2D (host_mem, stream)
    INTEGER(KIND=int_4), DIMENSION(:,:), &
      POINTER                                :: host_mem
    TYPE(acc_stream_type), INTENT(IN)        :: stream
    CHARACTER(len=*), PARAMETER :: routineN = 'acc_hostmem_dealloc_i_2D', &
      routineP = moduleN//':'//routineN

    IF (SIZE (host_mem) == 0) RETURN
#if defined (__ACC)
    CALL acc_hostmem_dealloc_raw(C_LOC(host_mem(1,1)), stream)
#else
    MARK_USED(host_mem)
    MARK_USED(stream)
    CPABORT("acc_hostmem_dealloc_i: ACC not compiled in.")
#endif
  END SUBROUTINE acc_hostmem_dealloc_i_2D
