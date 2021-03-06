! **************************************************************************************************
!> \brief the real driver routine for the multiply, not all symmetries implemented yet
!> \param matrix ...
!> \param vec_in ...
!> \param vec_out ...
!> \param alpha ...
!> \param beta ...
!> \param work_row ...
!> \param work_col ...
! **************************************************************************************************
  SUBROUTINE dbcsr_matrix_colvec_multiply_low_c(matrix, vec_in, vec_out, alpha, beta, work_row, work_col)
    TYPE(dbcsr_type)                          :: matrix, vec_in, vec_out
    COMPLEX(kind=real_4)                          :: alpha, beta
    TYPE(dbcsr_type)                          :: work_row, work_col

    CHARACTER(LEN=*), PARAMETER :: routineN = 'dbcsr_matrix_colvec_multiply_low', &
      routineP = moduleN//':'//routineN

    CHARACTER                                :: matrix_type

    matrix_type=dbcsr_get_matrix_type(matrix)
    SELECT CASE(matrix_type)
    CASE(dbcsr_type_no_symmetry)
       CALL dbcsr_matrix_vector_mult_c(matrix, vec_in, vec_out, alpha, beta, work_row, work_col)
    CASE(dbcsr_type_symmetric)
       CALL dbcsr_sym_matrix_vector_mult_c(matrix, vec_in, vec_out, alpha, beta, work_row, work_col)
    CASE(dbcsr_type_antisymmetric)
        ! Not yet implemented, should mainly be some prefactor magic, but who knows how antisymmetric matrices are stored???
       CPABORT("NYI, antisymmetric matrix not permitted")
    CASE DEFAULT
       CPABORT("Unknown matrix type, ...")
    END SELECT

  END SUBROUTINE dbcsr_matrix_colvec_multiply_low_c

! **************************************************************************************************
!> \brief low level routines for matrix vector multiplies
!> \param matrix ...
!> \param vec_in ...
!> \param vec_out ...
!> \param alpha ...
!> \param beta ...
!> \param work_row ...
!> \param work_col ...
! **************************************************************************************************
  SUBROUTINE dbcsr_matrix_vector_mult_c(matrix, vec_in, vec_out, alpha, beta, work_row, work_col)
    TYPE(dbcsr_type)                          :: matrix, vec_in, vec_out
    COMPLEX(kind=real_4)                          :: alpha, beta
    TYPE(dbcsr_type)                          :: work_row, work_col

    CHARACTER(LEN=*), PARAMETER :: routineN = 'dbcsr_matrix_vector_mult', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: col, mypcol, &
                                                myprow, &
                                                ncols, pcol_group, nrows, &
                                                prow_group, row, &
                                                handle, handle1, ithread 
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:), POINTER          :: data_vec
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: data_d, vec_res
    TYPE(dbcsr_distribution_obj)             :: distri
    TYPE(dbcsr_iterator)                     :: iter
    TYPE(fast_vec_access_type)               :: fast_vec_row, fast_vec_col
    INTEGER                                  :: prow, pcol

    CALL timeset(routineN, handle)
    ithread=0

! Collect some data about the parallel environment. We will use them later to move the vector around
    CALL dbcsr_get_info(matrix=matrix, distribution=distri)
    prow_group=distri%d%mp_env%mp%prow_group 
    pcol_group=distri%d%mp_env%mp%pcol_group 
    mypcol=distri%d%mp_env%mp%mypcol
    myprow=distri%d%mp_env%mp%myprow

    CALL create_fast_row_vec_access(work_row, fast_vec_row)
    CALL create_fast_col_vec_access(work_col, fast_vec_col)

! Transfer the correct parts of the input vector to the correct locations so we can do a local multiply
    CALL dbcsr_col_vec_to_rep_row_c(vec_in, work_col, work_row, fast_vec_col)

! Set the work vector for the results to 0
    CALL dbcsr_set(work_col, CMPLX(0.0, 0.0, real_4))

! Perform the local multiply. Here we exploit, that we have the blocks replicated on the mpi processes
! It is important to note, that the input and result vector are distributed differently (row wise, col wise respectively)
    CALL timeset(routineN//"_local_mm", handle1)

!$OMP PARALLEL DEFAULT(NONE) PRIVATE(row,col,iter,data_d,transposed,ithread,pcol,prow) &
!$OMP          SHARED(matrix,fast_vec_col,fast_vec_row)
    !$ ithread = omp_get_thread_num ()
    CALL dbcsr_iterator_start(iter, matrix, shared=.FALSE.)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, data_d, transposed)
       prow=hash_table_get(fast_vec_col%hash_table,row)
       IF(fast_vec_col%blk_map_c(prow)%assigned_thread .NE. ithread ) CYCLE
       pcol=hash_table_get(fast_vec_row%hash_table,col)
       fast_vec_col%blk_map_c(prow)%ptr=fast_vec_col%blk_map_c(prow)%ptr+&
            MATMUL(data_d,TRANSPOSE(fast_vec_row%blk_map_c(pcol)%ptr))
    END DO
    CALL dbcsr_iterator_stop(iter)
!$OMP END PARALLEL

    CALL timestop(handle1)

! sum all the data onto the first processor col where the original vector is stored
    data_vec => dbcsr_get_data_p (work_col%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    CALL dbcsr_get_info(matrix=work_col, nfullrows_local=nrows, nfullcols_local=ncols)
    CALL mp_sum(data_vec(1:nrows*ncols), prow_group)

! Local copy on the first mpi col (as this is the localtion of the vec_res blocks) of the result vector
! from the replicated to the original vector. Let's play it safe and use the iterator
    CALL dbcsr_iterator_start(iter, vec_out)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_res, transposed)
       prow=hash_table_get(fast_vec_col%hash_table,row)
       IF(ASSOCIATED(fast_vec_col%blk_map_c(prow)%ptr)) THEN
          vec_res(:, :)= beta*vec_res(:, :)+alpha*fast_vec_col%blk_map_c(prow)%ptr(:,:)
       ELSE
          vec_res(:, :)= beta*vec_res(:, :)
       END IF
    END DO
    CALL dbcsr_iterator_stop(iter)

    CALL release_fast_vec_access(fast_vec_row)
    CALL release_fast_vec_access(fast_vec_col)

    CALL timestop(handle)

  END SUBROUTINE dbcsr_matrix_vector_mult_c

! **************************************************************************************************
!> \brief ...
!> \param matrix ...
!> \param vec_in ...
!> \param vec_out ...
!> \param alpha ...
!> \param beta ...
!> \param work_row ...
!> \param work_col ...
!> \param skip_diag ...
! **************************************************************************************************
  SUBROUTINE dbcsr_matrixT_vector_mult_c(matrix, vec_in, vec_out, alpha, beta, work_row, work_col, skip_diag)
    TYPE(dbcsr_type)                          :: matrix, vec_in, vec_out
    COMPLEX(kind=real_4)                          :: alpha, beta
    TYPE(dbcsr_type)                          :: work_row, work_col
    LOGICAL                                  :: skip_diag

    CHARACTER(LEN=*), PARAMETER :: routineN = 'dbcsr_matrixT_vector_mult', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: col, col_size, mypcol, &
                                                myprow, &
                                                ncols, pcol_group, nrows, &
                                                prow_group, row, row_size, &
                                                handle, handle1, ithread
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:), POINTER          :: data_vec
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: data_d, vec_bl, vec_res
    TYPE(dbcsr_distribution_obj)             :: distri
    TYPE(dbcsr_iterator)                     :: iter

    TYPE(fast_vec_access_type)               :: fast_vec_row, fast_vec_col
    INTEGER                                  :: prow, pcol

    CALL timeset(routineN, handle)
    ithread=0

! Collect some data about the parallel environment. We will use them later to move the vector around
    CALL dbcsr_get_info(matrix=matrix, distribution=distri)
    prow_group=distri%d%mp_env%mp%prow_group; pcol_group=distri%d%mp_env%mp%pcol_group
    mypcol=distri%d%mp_env%mp%mypcol; myprow=distri%d%mp_env%mp%myprow

    CALL create_fast_row_vec_access(work_row, fast_vec_row)
    CALL create_fast_col_vec_access(work_col, fast_vec_col)

! Set the work vector for the results to 0
    CALL dbcsr_set(work_row, CMPLX(0.0, 0.0, real_4))

! Transfer the correct parts of the input vector to the replicated vector on proc_col 0
    CALL dbcsr_iterator_start(iter, vec_in)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_bl, transposed, row_size=row_size, col_size=col_size)
       prow=hash_table_get(fast_vec_col%hash_table,row)
       fast_vec_col%blk_map_c(prow)%ptr(1:row_size, 1:col_size)= vec_bl(1:row_size, 1:col_size)
    END DO
    CALL dbcsr_iterator_stop(iter)
! Replicate the data on all processore in the row
    data_vec => dbcsr_get_data_p (work_col%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    CALL mp_bcast(data_vec, 0, prow_group)

! Perform the local multiply. Here it is obvious why the vectors are replicated on the mpi rows and cols
    CALL timeset(routineN//"local_mm", handle1)
    CALL dbcsr_get_info(matrix=work_col, nfullcols_local=ncols)
!$OMP PARALLEL DEFAULT(NONE) PRIVATE(row,col,iter,data_d,row_size,col_size,transposed,ithread,prow,pcol) &
!$OMP          SHARED(matrix,fast_vec_row,fast_vec_col,skip_diag,ncols)
    !$ ithread = omp_get_thread_num ()
    CALL dbcsr_iterator_start(iter, matrix, shared=.FALSE.)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, data_d, transposed, row_size=row_size, col_size=col_size)
       IF(skip_diag.AND.col==row)CYCLE
       prow=hash_table_get(fast_vec_col%hash_table,row)
       pcol=hash_table_get(fast_vec_row%hash_table,col)
       IF ( ASSOCIATED(fast_vec_row%blk_map_c(pcol)%ptr) .AND. &
            ASSOCIATED(fast_vec_col%blk_map_c(prow)%ptr) )THEN
          IF(fast_vec_row%blk_map_c(pcol)%assigned_thread .NE. ithread ) CYCLE
          fast_vec_row%blk_map_c(pcol)%ptr=fast_vec_row%blk_map_c(pcol)%ptr+&
               MATMUL(TRANSPOSE(fast_vec_col%blk_map_c(prow)%ptr),data_d)
       ELSE
          prow=hash_table_get(fast_vec_row%hash_table,row)
          pcol=hash_table_get(fast_vec_col%hash_table,col)
          IF(fast_vec_row%blk_map_c(prow)%assigned_thread .NE. ithread ) CYCLE
          fast_vec_row%blk_map_c(prow)%ptr=fast_vec_row%blk_map_c(prow)%ptr+&
             MATMUL(TRANSPOSE(fast_vec_col%blk_map_c(pcol)%ptr),TRANSPOSE(data_d))
       END IF
    END DO
    CALL dbcsr_iterator_stop(iter)
!$OMP END PARALLEL

    CALL timestop(handle1)

! sum all the data within a processor column to obtain the replicated result
    data_vec => dbcsr_get_data_p (work_row%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
! we use the replicated vector but the final answer is only summed to proc_col 0 for efficiency
    CALL dbcsr_get_info(matrix=work_row, nfullrows_local=nrows, nfullcols_local=ncols)
    CALL mp_sum(data_vec(1:nrows*ncols), pcol_group)

! Convert the result to a column wise distribution
    CALL dbcsr_rep_row_to_rep_col_vec_c(work_col, work_row, fast_vec_row)
    
! Create_the final vector by summing it to the result vector which lives on proc_col 0
    CALL dbcsr_iterator_start(iter, vec_out)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_res, transposed, row_size=row_size)
       prow=hash_table_get(fast_vec_col%hash_table,row)
       IF(ASSOCIATED(fast_vec_col%blk_map_c(prow)%ptr)) THEN
          vec_res(:, :)= beta*vec_res(:, :)+alpha*fast_vec_col%blk_map_c(prow)%ptr(:,:)
       ELSE
          vec_res(:, :)= beta*vec_res(:, :)
       END IF
    END DO
    CALL dbcsr_iterator_stop(iter)

    CALL timestop(handle)

  END SUBROUTINE dbcsr_matrixT_vector_mult_c 

! **************************************************************************************************
!> \brief ...
!> \param vec_in ...
!> \param rep_col_vec ...
!> \param rep_row_vec ...
!> \param fast_vec_col ...
! **************************************************************************************************
  SUBROUTINE dbcsr_col_vec_to_rep_row_c(vec_in, rep_col_vec, rep_row_vec, fast_vec_col)
    TYPE(dbcsr_type)                          :: vec_in, rep_col_vec, &
                                                rep_row_vec
    TYPE(fast_vec_access_type), INTENT(IN)   :: fast_vec_col

    CHARACTER(LEN=*), PARAMETER :: routineN = 'dbcsr_col_vec_to_rep_row', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: col, mypcol, myprow, ncols, &
                                                nrows, pcol_group, &
                                                prow_group, row, handle
    INTEGER, DIMENSION(:), POINTER           :: local_cols, row_dist
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:), POINTER          :: data_vec, data_vec_rep
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: vec_row
    TYPE(dbcsr_distribution_obj)             :: distri
    TYPE(dbcsr_iterator)                     :: iter

    CALL timeset(routineN, handle)

! get information about the parallel environment
    CALL dbcsr_get_info(matrix=vec_in, distribution=distri)
    prow_group=distri%d%mp_env%mp%prow_group
    pcol_group=distri%d%mp_env%mp%pcol_group
    mypcol=distri%d%mp_env%mp%mypcol
    myprow=distri%d%mp_env%mp%myprow

! Get the vector which tells us which blocks are local to which processor row in the col vec
    row_dist=> dbcsr_distribution_row_dist (dbcsr_distribution(rep_col_vec))

! Copy the local vector to the replicated on the first processor column (this is where vec_in lives)
    CALL dbcsr_get_info(matrix=rep_col_vec, nfullrows_local=nrows, nfullcols_local=ncols)
    data_vec_rep => dbcsr_get_data_p (rep_col_vec%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    data_vec => dbcsr_get_data_p (vec_in%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    IF(mypcol==0)data_vec_rep(1:nrows*ncols)=data_vec(1:nrows*ncols)
! Replicate the data along the row
    CALL mp_bcast(data_vec_rep(1:nrows*ncols), 0, prow_group)

! Here it gets a bit tricky as we are dealing with two different parallel layouts:
! The rep_col_vec contains all blocks local to the row distribution of the vector. 
! The rep_row_vec only needs the fraction which is local to the col distribution.
! However in most cases this won't the complete set of block which can be obtained from col_vector p_row i
! Anyway, as the blocks don't repeat in the col_vec, a different fraction of the row vec will be available
! on every replica in the processor column, by summing along the column we end up with the complete vector everywhere
! Hope this clarifies the idea
    CALL dbcsr_set(rep_row_vec, CMPLX(0.0, 0.0, real_4))
    CALL dbcsr_get_info(matrix=rep_row_vec, nfullrows_local=nrows, local_cols=local_cols, nfullcols_local=ncols)
    CALL dbcsr_iterator_start(iter, rep_row_vec)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_row, transposed)
       IF(row_dist(col)==myprow)THEN
          vec_row=TRANSPOSE(fast_vec_col%blk_map_c(hash_table_get(fast_vec_col%hash_table,col))%ptr)
       END IF
    END DO
    CALL dbcsr_iterator_stop(iter)
    CALL dbcsr_get_info(matrix=rep_row_vec, nfullrows_local=nrows, nfullcols_local=ncols)
    data_vec_rep => dbcsr_get_data_p (rep_row_vec%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    CALL mp_sum(data_vec_rep(1:ncols*nrows), pcol_group)

    CALL timestop(handle)

  END SUBROUTINE dbcsr_col_vec_to_rep_row_c    
       
! **************************************************************************************************
!> \brief ...
!> \param rep_col_vec ...
!> \param rep_row_vec ...
!> \param fast_vec_row ...
!> \param fast_vec_col_add ...
! **************************************************************************************************
  SUBROUTINE dbcsr_rep_row_to_rep_col_vec_c(rep_col_vec, rep_row_vec, fast_vec_row, fast_vec_col_add)
    TYPE(dbcsr_type)                          :: rep_col_vec, rep_row_vec
    TYPE(fast_vec_access_type), OPTIONAL     :: fast_vec_col_add
    TYPE(fast_vec_access_type)               :: fast_vec_row

    CHARACTER(LEN=*), PARAMETER :: routineN = 'dbcsr_rep_row_to_rep_col_vec', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: col, mypcol, myprow, ncols, &
                                                nrows, pcol_group, &
                                                prow_group, row, handle
    INTEGER, DIMENSION(:), POINTER           :: col_dist
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:), POINTER          :: data_vec_rep
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: vec_col
    TYPE(dbcsr_distribution_obj)             :: distri
    TYPE(dbcsr_iterator)                     :: iter

    CALL timeset(routineN, handle)

! get information about the parallel environment
    CALL dbcsr_get_info(matrix=rep_col_vec, distribution=distri)
    prow_group=distri%d%mp_env%mp%prow_group
    pcol_group=distri%d%mp_env%mp%pcol_group
    mypcol=distri%d%mp_env%mp%mypcol
    myprow=distri%d%mp_env%mp%myprow
! Get the vector which tells us which blocks are local to which processor col in the row vec
    col_dist=> dbcsr_distribution_col_dist (dbcsr_distribution(rep_row_vec))

! The same trick as described above with opposite direction
    CALL dbcsr_set(rep_col_vec, CMPLX(0.0, 0.0, real_4))
    CALL dbcsr_iterator_start(iter, rep_col_vec)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_col, transposed)
       IF(col_dist(row)==mypcol)THEN
          vec_col=TRANSPOSE(fast_vec_row%blk_map_c(hash_table_get(fast_vec_row%hash_table,row))%ptr)
       END IF
       ! this one is special and allows to add the elements of a not yet summed replicated 
       ! column vector as it appears in M*V(row_rep) as result. Save an mp_sum in the symmetric case
       IF(PRESENT(fast_vec_col_add))vec_col=vec_col+&
            fast_vec_col_add%blk_map_c(hash_table_get(fast_vec_col_add%hash_table,row))%ptr(:,:)
    END DO
    CALL dbcsr_iterator_stop(iter)
    CALL dbcsr_get_info(matrix=rep_col_vec, nfullrows_local=nrows, nfullcols_local=ncols)
    data_vec_rep => dbcsr_get_data_p (rep_col_vec%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    CALL mp_sum(data_vec_rep(1:nrows*ncols), prow_group)

    CALL timestop(handle)

  END SUBROUTINE dbcsr_rep_row_to_rep_col_vec_c


! **************************************************************************************************
!> \brief given a column vector, prepare the fast_vec_access container
!> \param vec ...
!> \param fast_vec_access ...
! **************************************************************************************************
  SUBROUTINE create_fast_col_vec_access_c(vec, fast_vec_access)
    TYPE(dbcsr_type)                          :: vec
    TYPE(fast_vec_access_type)               :: fast_vec_access

    CHARACTER(LEN=*), PARAMETER :: routineN = 'create_fast_col_vec_access_c', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: handle, nblk_local
    INTEGER                                  :: col, row, iblock, nthreads
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: vec_bl
    TYPE(dbcsr_iterator)                     :: iter

    CALL timeset(routineN, handle)

    ! figure out the number of threads
    nthreads = 1
!$OMP PARALLEL DEFAULT(NONE) SHARED(nthreads)
!$OMP MASTER
    !$ nthreads = OMP_GET_NUM_THREADS()
!$OMP END MASTER
!$OMP END PARALLEL

    CALL dbcsr_get_info(matrix=vec, nblkrows_local=nblk_local)
    ! 4 times makes sure the table is big enough to limit collisions.
    CALL hash_table_create(fast_vec_access%hash_table,4*nblk_local)
    ! include zero for effective dealing with values not in the hash table (will return 0)
    ALLOCATE(fast_vec_access%blk_map_c(0:nblk_local))

    CALL dbcsr_get_info(matrix=vec, nblkcols_local=col)
    IF (col.GT.1) CPABORT("BUG")

    ! go through the blocks of the vector
    iblock=0
    CALL dbcsr_iterator_start(iter, vec)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_bl, transposed)
       iblock=iblock+1
       CALL hash_table_add(fast_vec_access%hash_table,row,iblock)
       fast_vec_access%blk_map_c(iblock)%ptr=>vec_bl
       fast_vec_access%blk_map_c(iblock)%assigned_thread=MOD(iblock,nthreads)
    END DO
    CALL dbcsr_iterator_stop(iter)

    CALL timestop(handle)

  END SUBROUTINE create_fast_col_vec_access_c

! **************************************************************************************************
!> \brief given a row vector, prepare the fast_vec_access_container
!> \param vec ...
!> \param fast_vec_access ...
! **************************************************************************************************
  SUBROUTINE create_fast_row_vec_access_c(vec, fast_vec_access)
    TYPE(dbcsr_type)                          :: vec
    TYPE(fast_vec_access_type)               :: fast_vec_access

    CHARACTER(LEN=*), PARAMETER :: routineN = 'create_fast_row_vec_access_c', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: handle, nblk_local
    INTEGER                                  :: col, row, iblock, nthreads
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: vec_bl
    TYPE(dbcsr_iterator)                     :: iter

    CALL timeset(routineN, handle)

    ! figure out the number of threads
    nthreads = 1
!$OMP PARALLEL DEFAULT(NONE) SHARED(nthreads)
!$OMP MASTER
    !$ nthreads = OMP_GET_NUM_THREADS()
!$OMP END MASTER
!$OMP END PARALLEL

    CALL dbcsr_get_info(matrix=vec, nblkcols_local=nblk_local)
    ! 4 times makes sure the table is big enough to limit collisions.
    CALL hash_table_create(fast_vec_access%hash_table,4*nblk_local)
    ! include zero for effective dealing with values not in the hash table (will return 0)
    ALLOCATE(fast_vec_access%blk_map_c(0:nblk_local))

    ! sanity check
    CALL dbcsr_get_info(matrix=vec, nblkrows_local=row)
    IF (row.GT.1) CPABORT("BUG")

    ! go through the blocks of the vector
    iblock=0
    CALL dbcsr_iterator_start(iter, vec)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_bl, transposed)
       iblock=iblock+1
       CALL hash_table_add(fast_vec_access%hash_table,col,iblock)
       fast_vec_access%blk_map_c(iblock)%ptr=>vec_bl
       fast_vec_access%blk_map_c(iblock)%assigned_thread=MOD(iblock,nthreads)
    END DO
    CALL dbcsr_iterator_stop(iter)

    CALL timestop(handle)

  END SUBROUTINE create_fast_row_vec_access_c

! **************************************************************************************************
!> \brief ...
!> \param matrix ...
!> \param vec_in ...
!> \param vec_out ...
!> \param alpha ...
!> \param beta ...
!> \param work_row ...
!> \param work_col ...
! **************************************************************************************************
  SUBROUTINE dbcsr_sym_matrix_vector_mult_c(matrix, vec_in, vec_out, alpha, beta, work_row, work_col)
    TYPE(dbcsr_type)                          :: matrix, vec_in, vec_out
    COMPLEX(kind=real_4)                          :: alpha, beta
    TYPE(dbcsr_type)                          :: work_row, work_col

    CHARACTER(LEN=*), PARAMETER :: routineN = 'dbcsr_sym_m_v_mult', &
      routineP = moduleN//':'//routineN

    INTEGER                                  :: col, mypcol, &
                                                myprow, &
                                                pcol_group, nrows, ncols,&
                                                prow_group, row, &
                                                handle, handle1, ithread, vec_dim
    LOGICAL                                  :: transposed
    COMPLEX(kind=real_4), DIMENSION(:), POINTER          :: data_vec
    COMPLEX(kind=real_4), DIMENSION(:, :), POINTER       :: data_d, vec_res
    TYPE(dbcsr_distribution_obj)             :: distri
    TYPE(dbcsr_iterator)                     :: iter
    TYPE(dbcsr_type)                          :: result_row, result_col

    TYPE(fast_vec_access_type)               :: fast_vec_row, fast_vec_col, res_fast_vec_row, res_fast_vec_col
    INTEGER                                  :: prow, pcol, rprow, rpcol

    CALL timeset(routineN, handle)
    ithread=0
! We need some work matrices as we try to exploit operations on the replicated vectors which are duplicated otherwise
    CALL dbcsr_get_info(matrix=vec_in,nfullcols_total=vec_dim)
! This is a performance hack as the new creation of a replicated vector is a fair bit more expensive
    CALL dbcsr_set(work_col, CMPLX(0.0, 0.0, real_4))
    CALL dbcsr_copy(result_col, work_col)
    CALL dbcsr_set(work_row, CMPLX(0.0, 0.0, real_4))
    CALL dbcsr_copy(result_row, work_row)

! Collect some data about the parallel environment. We will use them later to move the vector around
    CALL dbcsr_get_info(matrix=matrix, distribution=distri)
    prow_group=distri%d%mp_env%mp%prow_group; pcol_group=distri%d%mp_env%mp%pcol_group
    mypcol=distri%d%mp_env%mp%mypcol; myprow=distri%d%mp_env%mp%myprow

    CALL create_fast_row_vec_access(work_row, fast_vec_row)
    CALL create_fast_col_vec_access(work_col, fast_vec_col)
    CALL create_fast_row_vec_access(result_row, res_fast_vec_row)
    CALL create_fast_col_vec_access(result_col, res_fast_vec_col)

! Transfer the correct parts of the input vector to the correct locations so we can do a local multiply
    CALL dbcsr_col_vec_to_rep_row_c(vec_in, work_col, work_row, fast_vec_col)

! Probably I should rename the routine above as it delivers both the replicated row and column vector

! Perform the local multiply. Here we exploit, that we have the blocks replicated on the mpi processes
! It is important to note, that the input and result vector are distributed differently (row wise, col wise respectively)
    CALL timeset(routineN//"_local_mm", handle1)

!------ perform the multiplication, we have to take car to take the correct blocks ----------

!$OMP PARALLEL DEFAULT(NONE) PRIVATE(row,col,iter,data_d,transposed,ithread,pcol,prow,rpcol,rprow) &
!$OMP          SHARED(matrix,fast_vec_row,res_fast_vec_col,res_fast_vec_row,fast_vec_col)
    !$ ithread = omp_get_thread_num ()
    CALL dbcsr_iterator_start(iter, matrix, shared=.FALSE.)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, data_d, transposed)
       pcol=hash_table_get(fast_vec_row%hash_table,col)
       rprow=hash_table_get(res_fast_vec_col%hash_table,row)
       IF(ASSOCIATED(fast_vec_row%blk_map_c(pcol)%ptr) .AND.&
          ASSOCIATED(res_fast_vec_col%blk_map_c(rprow)%ptr))THEN
          IF(res_fast_vec_col%blk_map_c(rprow)%assigned_thread .EQ. ithread ) THEN
             res_fast_vec_col%blk_map_c(rprow)%ptr=res_fast_vec_col%blk_map_c(rprow)%ptr+&
               MATMUL(data_d,TRANSPOSE(fast_vec_row%blk_map_c(pcol)%ptr))
          END IF
          prow=hash_table_get(fast_vec_col%hash_table,row)
          rpcol=hash_table_get(res_fast_vec_row%hash_table,col)
          IF(res_fast_vec_row%blk_map_c(rpcol)%assigned_thread .EQ. ithread .AND. row .NE. col) THEN
             res_fast_vec_row%blk_map_c(rpcol)%ptr=res_fast_vec_row%blk_map_c(rpcol)%ptr+&
                MATMUL(TRANSPOSE(fast_vec_col%blk_map_c(prow)%ptr),data_d)
          END IF
       ELSE
          rpcol=hash_table_get(res_fast_vec_col%hash_table,col)
          prow=hash_table_get(fast_vec_row%hash_table,row)
          IF(res_fast_vec_col%blk_map_c(rpcol)%assigned_thread .EQ. ithread ) THEN
             res_fast_vec_col%blk_map_c(rpcol)%ptr=res_fast_vec_col%blk_map_c(rpcol)%ptr+&
                TRANSPOSE(MATMUL(fast_vec_row%blk_map_c(prow)%ptr,data_d))
          END IF
          rprow=hash_table_get(res_fast_vec_row%hash_table,row)
          pcol=hash_table_get(fast_vec_col%hash_table,col)
          IF(res_fast_vec_row%blk_map_c(rprow)%assigned_thread .EQ. ithread  .AND. row .NE. col ) THEN
             res_fast_vec_row%blk_map_c(rprow)%ptr=res_fast_vec_row%blk_map_c(rprow)%ptr+&
                TRANSPOSE(MATMUL(data_d,fast_vec_col%blk_map_c(pcol)%ptr))
          END IF
       END IF 
    END DO
    CALL dbcsr_iterator_stop(iter)
!$OMP END PARALLEL

    CALL timestop(handle1)

    ! sum all the data within a processor column to obtain the replicated result from lower
    data_vec => dbcsr_get_data_p (result_row%data_area, select_data_type=CMPLX(0.0, 0.0, real_4))
    CALL dbcsr_get_info(matrix=result_row, nfullrows_local=nrows, nfullcols_local=ncols)

    CALL mp_sum(data_vec(1:nrows*ncols), pcol_group)
!
!! Convert the results to a column wise distribution, this is a bit involved as the result_row is fully replicated
!! While the result_col still has the partial results in parallel. The routine below takes care of that and saves an
!! mp_sum. Of the res_row vectors are created only taking the approriate element (0 otherwise) while the res_col
!! parallel bits are locally added. The mp_sum magically creates the correct vector
    CALL dbcsr_rep_row_to_rep_col_vec_c(work_col, result_row, res_fast_vec_row, res_fast_vec_col)

!    ! Create_the final vector by summing it to the result vector which lives on proc_col 0 lower
    CALL dbcsr_iterator_start(iter, vec_out)
    DO WHILE (dbcsr_iterator_blocks_left(iter))
       CALL dbcsr_iterator_next_block(iter, row, col, vec_res, transposed)
       prow=hash_table_get(fast_vec_col%hash_table,row)
       IF(ASSOCIATED(fast_vec_col%blk_map_c(prow)%ptr))THEN
          vec_res(:, :)= beta*vec_res(:, :)+alpha*(fast_vec_col%blk_map_c(prow)%ptr(:, :)) 
       ELSE
          vec_res(:, :)= beta*vec_res(:, :)
       END IF
    END DO
    CALL dbcsr_iterator_stop(iter)

    CALL release_fast_vec_access(fast_vec_row)
    CALL release_fast_vec_access(fast_vec_col)
    CALL release_fast_vec_access(res_fast_vec_row)
    CALL release_fast_vec_access(res_fast_vec_col)

    CALL dbcsr_release(result_row); CALL dbcsr_release(result_col)

    CALL timestop(handle)

  END SUBROUTINE dbcsr_sym_matrix_vector_mult_c

