!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2017  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!

!--------------------------------------------------------------------------------------------------!
! Generated from dbcsr_tensor_types.fypp using Fypp.                                               !
! **DO NOT** modify this file, edit dbcsr_tensor_types.fypp instead.                               !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief DBCSR tensor framework for block-sparse tensor contraction: Types and create/destroy
!>        routines.
!> \author Patrick Seewald
! **************************************************************************************************
MODULE dbcsr_tensor_types
   USE array_list_methods,              ONLY: array_list,&
                                              array_offsets,&
                                              create_array_list,&
                                              destroy_array_list,&
                                              get_array_elements,&
                                              sizes_of_arrays,&
                                              sum_of_arrays
   USE dbcsr_api,                       ONLY: &
        dbcsr_col_block_sizes, dbcsr_create, dbcsr_distribution, dbcsr_distribution_col_dist, &
        dbcsr_distribution_mp, dbcsr_distribution_new, dbcsr_distribution_obj, &
        dbcsr_distribution_release, dbcsr_distribution_row_dist, dbcsr_finalize, &
        dbcsr_get_data_type, dbcsr_mp_group, dbcsr_mp_new, dbcsr_mp_obj, dbcsr_mp_release, &
        dbcsr_name, dbcsr_release, dbcsr_row_block_sizes, dbcsr_type
   USE dbcsr_tensor_index,              ONLY: create_nd_to_2d_mapping,&
                                              destroy_nd_to_2d_mapping,&
                                              get_2d_indices,&
                                              get_mapping_info,&
                                              get_nd_indices,&
                                              nd_to_2d_mapping
   USE kinds,                           ONLY: default_string_length
   USE message_passing,                 ONLY: mp_cart_create,&
                                              mp_cart_rank,&
                                              mp_dims_create,&
                                              mp_environ
#include "../base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'dbcsr_tensor_types'

   PUBLIC  :: &
      dbcsr_t_blk_offsets, &
      dbcsr_t_blk_sizes, &
      dbcsr_t_create, &
      dbcsr_t_destroy, &
      dbcsr_t_distribution_destroy, &
      dbcsr_t_distribution_new, &
      dbcsr_t_distribution_type, &
      dbcsr_t_get_data_type, &
      dbcsr_t_nd_mp_comm, &
      dbcsr_t_type, &
      dims_tensor, &
      ndims_tensor

   TYPE dbcsr_t_type
      TYPE(dbcsr_type)                      :: matrix_rep
      TYPE(nd_to_2d_mapping)               :: nd_index_blk
      TYPE(nd_to_2d_mapping)               :: nd_index
      TYPE(array_list)                     :: blk_sizes
      TYPE(array_list)                     :: blk_offsets
      TYPE(array_list)                     :: nd_dist
      INTEGER                              :: comm_nd
      LOGICAL                              :: valid = .FALSE.
      CHARACTER(LEN=default_string_length) :: name
   END TYPE dbcsr_t_type

   TYPE dbcsr_t_distribution_type
      TYPE(dbcsr_distribution_obj) :: dist
      INTEGER                      :: comm_nd
      TYPE(array_list)             :: nd_dist
   END TYPE

   INTERFACE dbcsr_t_create
      MODULE PROCEDURE dbcsr_t_create_new
      MODULE PROCEDURE dbcsr_t_create_template
   END INTERFACE

CONTAINS

! **************************************************************************************************
!> \brief Create a default nd process topology that is consistent with a given 2d topology.
!>        Purpose: a nd tensor defined on the returned process grid can be represented as a DBCSR
!>        matrix with the given 2d topology.
!>        This is needed to enable contraction of 2 tensors (must have the same 2d process grid).
!> \param comm_2d communicator with 2-dimensional topology
!> \param map1_2d which nd-indices map to first matrix index and in which order
!> \param map2_2d which nd-indices map to second matrix index and in which order
!> \retval communicator with nd cartesian grid
! **************************************************************************************************
   FUNCTION dbcsr_t_nd_mp_comm(comm_2d, map1_2d, map2_2d)
      INTEGER, INTENT(IN)                                :: comm_2d
      INTEGER, DIMENSION(:), INTENT(IN)                  :: map1_2d, map2_2d
      INTEGER                                            :: dbcsr_t_nd_mp_comm

      INTEGER                                            :: i, ndim1, ndim2, numtask
      INTEGER, DIMENSION(2)                              :: dims_2d, task_coor
      INTEGER, DIMENSION(SIZE(map1_2d))                  :: dims1_nd
      INTEGER, DIMENSION(SIZE(map1_2d)+SIZE(map2_2d))    :: dims_nd, pos
      INTEGER, DIMENSION(SIZE(map2_2d))                  :: dims2_nd

      ndim1 = SIZE(map1_2d); ndim2 = SIZE(map2_2d)

      CALL mp_environ(numtask, dims_2d, task_coor, comm_2d)

      dims1_nd(:) = 0; dims2_nd(:) = 0
      CALL mp_dims_create(dims_2d(1), dims1_nd)
      CALL mp_dims_create(dims_2d(2), dims2_nd)

      DO i = 1, SIZE(map1_2d)
         dims_nd(map1_2d(i)) = dims1_nd(i)
      ENDDO

      DO i = 1, SIZE(map2_2d)
         dims_nd(map2_2d(i)) = dims2_nd(i)
      ENDDO

      CALL mp_cart_create(comm_2d, ndim1+ndim2, dims_nd, pos, dbcsr_t_nd_mp_comm)

   END FUNCTION

! **************************************************************************************************
!> \brief Create a tensor distribution.
!>
!> comm_nd and comm_2d must be consistent (the nd process grid must map to the 2d process grid
!> according to map1_2d and map2_2d).
!> comm_2d is only needed for an early testing phase of tensor contraction and in the future,
!> comm_2d should not be an input.
!> \param dist ...
!> \param comm_nd communicator with n-dimensional Cartesian topology
!> \param comm_2d communicator with 2-dimensional topology
!> \param map1_2d which nd-indices map to first matrix index and in which order
!> \param map2_2d which nd-indices map to second matrix index and in which order
!> \param nd_dist_1 distribution vector for first dimension
!> \param nd_dist_2 distribution vector for second dimension
!> \param nd_dist_3 ...
!> \param nd_dist_4 ...
! **************************************************************************************************
   SUBROUTINE dbcsr_t_distribution_new(dist, comm_nd, comm_2d, map1_2d, map2_2d, nd_dist_1, nd_dist_2, nd_dist_3, nd_dist_4)

      TYPE(dbcsr_t_distribution_type), INTENT(OUT)       :: dist
      INTEGER, INTENT(IN)                                :: comm_nd, comm_2d
      INTEGER, DIMENSION(:), INTENT(IN)                  :: map1_2d, map2_2d
      INTEGER, DIMENSION(:), INTENT(IN), OPTIONAL        :: nd_dist_1, nd_dist_2, nd_dist_3, &
                                                            nd_dist_4

      INTEGER                                            :: bcol, brow, mynode, ndims, numnodes, &
                                                            pcol, prow
      INTEGER, ALLOCATABLE, DIMENSION(:, :)              :: pgrid
      INTEGER, DIMENSION(2)                              :: bdims_2d, coord, dist_2d, pdims_2d, &
                                                            pdims_2d_check, task_coor_2d
      INTEGER, DIMENSION(:), POINTER                     :: col_dist, row_dist
      INTEGER, DIMENSION(SIZE(map1_2d)+SIZE(map2_2d))    :: dims, ind, nblks_nd, task_coor
      LOGICAL, DIMENSION(2)                              :: periods_2d
      LOGICAL, DIMENSION(SIZE(map1_2d)+SIZE(map2_2d))    :: periods
      TYPE(array_list)                                   :: nd_dist
      TYPE(dbcsr_mp_obj)                                 :: mp_env
      TYPE(nd_to_2d_mapping)                             :: map_blks, map_grid

      ndims = SIZE(map1_2d)+SIZE(map2_2d)
      CPASSERT(ndims .GE. 2 .AND. ndims .LE. 4)

      CALL create_array_list(nd_dist, ndims, nd_dist_1, nd_dist_2, nd_dist_3, nd_dist_4)

      nblks_nd(:) = sizes_of_arrays(nd_dist)

      CALL mp_environ(numnodes, mynode, comm_nd)

      ! check that 2d process topology is consistent with nd topology.
      CALL mp_environ(comm_nd, ndims, dims, task_coor, periods)

      ! process grid index mapping
      CALL create_nd_to_2d_mapping(map_grid, dims, map1_2d, map2_2d, base=0, col_major=.FALSE.)

      ! blk index mapping
      CALL create_nd_to_2d_mapping(map_blks, nblks_nd, map1_2d, map2_2d)

      CALL get_mapping_info(map_grid, dims_2d=pdims_2d)
      CALL get_mapping_info(map_blks, dims_2d=bdims_2d)

      CALL mp_environ(comm_2d, 2, pdims_2d_check, task_coor_2d, periods_2d)
      IF (ANY(pdims_2d_check .NE. pdims_2d)) THEN
         CPABORT("inconsistent process grid dimensions")
      ENDIF

      ALLOCATE (pgrid(0:pdims_2d(1)-1, 0:pdims_2d(2)-1))
      DO prow = 0, pdims_2d(1)-1
         DO pcol = 0, pdims_2d(2)-1
            coord = (/prow, pcol/)
            CALL mp_cart_rank(comm_2d, coord, pgrid(prow, pcol))
         ENDDO
      ENDDO

      CALL mp_environ(numnodes, mynode, comm_2d)

      ! setup the mp enviroment
      CALL dbcsr_mp_new(mp_env, pgrid, comm_2d, mynode, numnodes, &
                        myprow=task_coor_2d(1), mypcol=task_coor_2d(2))

      ! create 2d distribution from nd distribution
      ALLOCATE (row_dist(bdims_2d(1)), col_dist(bdims_2d(2)))
      row_dist(:) = -1
      col_dist(:) = -1

      DO brow = 1, bdims_2d(1) ! blk rows
         DO bcol = 1, bdims_2d(2) ! blk cols

            ! 2d blk index to nd blk index
            ind(:) = get_nd_indices(map_blks, [brow, bcol])

            ! nd distribution to 2d distribution, mapped using proc grid
            dist_2d(:) = get_2d_indices(map_grid, get_array_elements(nd_dist, ind))

            ! first index maps to columns, second index to rows (row-major)
            IF (row_dist(brow) .LT. 0) row_dist(brow) = dist_2d(1)
            IF (col_dist(bcol) .LT. 0) col_dist(bcol) = dist_2d(2)
         ENDDO
      ENDDO

      CALL dbcsr_distribution_new(dist%dist, mp_env, row_dist, col_dist, reuse_arrays=.TRUE.)
      dist%nd_dist = nd_dist
      dist%comm_nd = comm_nd

      CALL dbcsr_mp_release(mp_env)

   END SUBROUTINE

! **************************************************************************************************
!> \brief Destroy tensor distribution
!> \param dist ...
! **************************************************************************************************
   SUBROUTINE dbcsr_t_distribution_destroy(dist)
      TYPE(dbcsr_t_distribution_type), INTENT(INOUT)     :: dist

      CALL dbcsr_distribution_release(dist%dist)
      CALL destroy_array_list(dist%nd_dist)
   END SUBROUTINE

! **************************************************************************************************
!> \brief create a tensor
!> \param tensor ...
!> \param name ...
!> \param dist ...
!> \param map1_2d which nd-indices to map to first 2d index and in which order
!> \param map2_2d which nd-indices to map to first 2d index and in which order
!> \param data_type ...
!> \param blk_size_1 blk sizes in each dimension
!> \param blk_size_2 ...
!> \param blk_size_3 ...
!> \param blk_size_4 ...
! **************************************************************************************************
   SUBROUTINE dbcsr_t_create_new(tensor, name, dist, map1_2d, map2_2d, data_type, &
                                 blk_size_1, blk_size_2, blk_size_3, blk_size_4)
      TYPE(dbcsr_t_type), INTENT(OUT)                    :: tensor
      CHARACTER(len=*), INTENT(IN)                       :: name
      TYPE(dbcsr_t_distribution_type), INTENT(INOUT)     :: dist
      INTEGER, DIMENSION(:), INTENT(IN)                  :: map1_2d, map2_2d
      INTEGER, INTENT(IN), OPTIONAL                      :: data_type
      INTEGER, DIMENSION(:), INTENT(IN), OPTIONAL        :: blk_size_1, blk_size_2, blk_size_3, &
                                                            blk_size_4

      INTEGER                                            :: icol, imap, irow, ndims
      INTEGER, DIMENSION(2)                              :: dims_2d
      INTEGER, DIMENSION(:), POINTER                     :: col_blk_size, row_blk_size
      INTEGER, DIMENSION(SIZE(map1_2d)+SIZE(map2_2d))    :: blk_dims, dims, nd_ind
      TYPE(array_list)                                   :: blk_size
      TYPE(nd_to_2d_mapping)                             :: map

      ndims = SIZE(map1_2d)+SIZE(map2_2d)
      CALL create_array_list(blk_size, ndims, blk_size_1, blk_size_2, blk_size_3, blk_size_4)
      dims = sizes_of_arrays(blk_size)

      CALL create_nd_to_2d_mapping(map, dims, map1_2d, map2_2d)
      CALL get_mapping_info(map, dims_2d=dims_2d)

      ALLOCATE (row_blk_size(dims_2d(1)), col_blk_size(dims_2d(2)))
      row_blk_size(:) = -1
      col_blk_size(:) = -1

      DO irow = 1, dims_2d(1)
         DO icol = 1, dims_2d(2)
            nd_ind(:) = get_nd_indices(map, [irow, icol])
            blk_dims(:) = get_array_elements(blk_size, nd_ind)
            IF (row_blk_size(irow) .LT. 0) THEN
               row_blk_size(irow) = 1
               DO imap = 1, SIZE(map1_2d)
                  row_blk_size(irow) = row_blk_size(irow)*blk_dims(map1_2d(imap))
               ENDDO
            ENDIF
            IF (col_blk_size(icol) .LT. 0) THEN
               col_blk_size(icol) = 1
               DO imap = 1, SIZE(map2_2d)
                  col_blk_size(icol) = col_blk_size(icol)*blk_dims(map2_2d(imap))
               ENDDO
            ENDIF
         ENDDO
      ENDDO

      CALL dbcsr_create(matrix=tensor%matrix_rep, &
                        name=name//"_matrix_rep", &
                        dist=dist%dist, &
                        matrix_type='N', &
                        row_blk_size=row_blk_size, &
                        col_blk_size=col_blk_size, &
                        data_type=data_type, &
                        reuse_arrays=.TRUE.)

      tensor%nd_index_blk = map
      tensor%name = name

      CALL dbcsr_finalize(tensor%matrix_rep)
      CALL destroy_nd_to_2d_mapping(map)

      ! map element-wise tensor index
      CALL create_nd_to_2d_mapping(map, sum_of_arrays(blk_size), map1_2d, map2_2d)
      tensor%nd_index = map
      tensor%blk_sizes = blk_size
      tensor%nd_dist = dist%nd_dist
      tensor%comm_nd = dist%comm_nd

      CALL array_offsets(tensor%blk_sizes, tensor%blk_offsets)

      tensor%valid = .TRUE.
   END SUBROUTINE

! **************************************************************************************************
!> \brief create a tensor from template
!> \param tensor_in ...
!> \param tensor ...
!> \param name ...
! **************************************************************************************************
   SUBROUTINE dbcsr_t_create_template(tensor_in, tensor, name)
      TYPE(dbcsr_t_type), INTENT(INOUT)                  :: tensor_in
      TYPE(dbcsr_t_type), INTENT(OUT)                    :: tensor
      CHARACTER(len=*), INTENT(IN), OPTIONAL             :: name

      CALL dbcsr_create(tensor%matrix_rep, template=tensor_in%matrix_rep)
      CALL dbcsr_finalize(tensor%matrix_rep)

      tensor%nd_index_blk = tensor_in%nd_index_blk
      tensor%nd_index = tensor_in%nd_index
      tensor%blk_sizes = tensor_in%blk_sizes
      tensor%blk_offsets = tensor_in%blk_offsets
      tensor%nd_dist = tensor_in%nd_dist
      tensor%comm_nd = tensor_in%comm_nd
      tensor%valid = .TRUE.
      IF (PRESENT(name)) THEN
         tensor%name = name
      ELSE
         tensor%name = tensor_in%name
      ENDIF
   END SUBROUTINE

! **************************************************************************************************
!> \brief Create 2-rank tensor from matrix.
!> \param matrix_in ...
!> \param tensor ...
!> \param order ...
!> \param name ...
! **************************************************************************************************
   SUBROUTINE dbcsr_t_create_matrix(matrix_in, tensor, order, name)
      TYPE(dbcsr_type), INTENT(IN)                       :: matrix_in
      TYPE(dbcsr_t_type), INTENT(OUT)                    :: tensor
      INTEGER, DIMENSION(2), INTENT(IN), OPTIONAL        :: order
      CHARACTER(len=*), INTENT(IN), OPTIONAL             :: name

      CHARACTER(len=default_string_length)               :: name_in
      INTEGER                                            :: comm_2d, comm_nd
      INTEGER, DIMENSION(2)                              :: order_in
      TYPE(dbcsr_distribution_obj)                       :: matrix_dist
      TYPE(dbcsr_t_distribution_type)                    :: dist

      IF (PRESENT(name)) THEN
         name_in = name
      ELSE
         name_in = dbcsr_name(matrix_in)
      ENDIF

      IF (PRESENT(order)) THEN
         order_in = order
      ELSE
         order_in = [1, 2]
      ENDIF

      matrix_dist = dbcsr_distribution(matrix_in)

      comm_2d = dbcsr_mp_group(dbcsr_distribution_mp(matrix_dist))
      comm_nd = dbcsr_t_nd_mp_comm(comm_2d, [order_in(1)], [order_in(2)])

      CALL dbcsr_t_distribution_new( &
         dist, &
         comm_nd, comm_2d, &
         [order_in(1)], [order_in(2)], &
         dbcsr_distribution_row_dist(matrix_dist), &
         dbcsr_distribution_col_dist(matrix_dist))

      CALL dbcsr_t_create_new(tensor, name_in, dist, &
                              [order_in(1)], [order_in(2)], &
                              dbcsr_get_data_type(matrix_in), &
                              dbcsr_row_block_sizes(matrix_in), &
                              dbcsr_col_block_sizes(matrix_in))
   END SUBROUTINE

! **************************************************************************************************
!> \brief ...
!> \param tensor ...
! **************************************************************************************************
   SUBROUTINE dbcsr_t_destroy(tensor)
      TYPE(dbcsr_t_type), INTENT(INOUT)                  :: tensor

      CALL dbcsr_release(tensor%matrix_rep)
      CALL destroy_nd_to_2d_mapping(tensor%nd_index_blk)
      CALL destroy_nd_to_2d_mapping(tensor%nd_index)
      CALL destroy_array_list(tensor%blk_sizes)
      CALL destroy_array_list(tensor%blk_offsets)
      CALL destroy_array_list(tensor%nd_dist)
      tensor%valid = .FALSE.
      tensor%name = ""
   END SUBROUTINE

! **************************************************************************************************
!> \brief tensor rank
!> \param tensor ...
!> \retval ndims_tensor ...
! **************************************************************************************************
   PURE FUNCTION ndims_tensor(tensor)
      TYPE(dbcsr_t_type), INTENT(IN)                     :: tensor
      INTEGER                                            :: ndims_tensor

      ndims_tensor = tensor%nd_index%ndim_nd
   END FUNCTION

! **************************************************************************************************
!> \brief tensor dimensions
!> \param tensor ...
!> \param dims ...
! **************************************************************************************************
   SUBROUTINE dims_tensor(tensor, dims)
      TYPE(dbcsr_t_type), INTENT(IN)                     :: tensor
      INTEGER, DIMENSION(ndims_tensor(tensor)), &
         INTENT(OUT)                                     :: dims

      CPASSERT(tensor%valid)
      dims(:) = tensor%nd_index%dims_nd(:)
   END SUBROUTINE

! **************************************************************************************************
!> \brief tensor data type
!> \param tensor ...
!> \retval dbcsr_t_get_data_type ...
! **************************************************************************************************
   PURE FUNCTION dbcsr_t_get_data_type(tensor)
      TYPE(dbcsr_t_type), INTENT(IN)                     :: tensor
      INTEGER                                            :: dbcsr_t_get_data_type

      dbcsr_t_get_data_type = dbcsr_get_data_type(tensor%matrix_rep)
   END FUNCTION

! **************************************************************************************************
!> \brief Size of tensor block
!> \param tensor ...
!> \param ind block index
!> \param blk_size block size
! **************************************************************************************************
   SUBROUTINE dbcsr_t_blk_sizes(tensor, ind, blk_size)
      TYPE(dbcsr_t_type), INTENT(IN)                     :: tensor
      INTEGER, DIMENSION(ndims_tensor(tensor)), &
         INTENT(IN)                                      :: ind
      INTEGER, DIMENSION(ndims_tensor(tensor)), &
         INTENT(OUT)                                     :: blk_size

      blk_size(:) = get_array_elements(tensor%blk_sizes, ind)
   END SUBROUTINE

! **************************************************************************************************
!> \brief offset of tensor block
!> \param tensor ...
!> \param ind block index
!> \param blk_offset block offset
! **************************************************************************************************
   SUBROUTINE dbcsr_t_blk_offsets(tensor, ind, blk_offset)
      TYPE(dbcsr_t_type), INTENT(IN)                     :: tensor
      INTEGER, DIMENSION(ndims_tensor(tensor)), &
         INTENT(IN)                                      :: ind
      INTEGER, DIMENSION(ndims_tensor(tensor)), &
         INTENT(OUT)                                     :: blk_offset

      CPASSERT(tensor%valid)
      blk_offset(:) = get_array_elements(tensor%blk_offsets, ind)
   END SUBROUTINE

END MODULE
