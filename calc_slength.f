      PROGRAM CALC_SLENGTH
      USE ANGSYM
      REAL*8 :: RADA, SLENGTH
      INTEGER :: MODEL, NDVR, LMAX, MAN, LAN, KSYM, NANG, NSPS
      INTEGER, ALLOCATABLE :: L(:), M(:)
      COMPLEX*16, ALLOCATABLE :: CK(:)
      CHARACTER(30) :: STR, FILENAME, SYMNAME
      
      IF (IARGC() .LT. 7) STOP 'AT LEAST 7 PARAMETERS REQUIRED'
      CALL GETARG(1, STR)
      READ(STR,*) MODEL
      CALL GETARG(2, STR)
      READ(STR,*) RADA
      CALL GETARG(3, STR)
      READ(STR,*) NDVR
      CALL GETARG(4, STR)
      READ(STR,*) LMAX
      CALL GETARG(5, STR)
      READ(STR,*) LAN
      CALL GETARG(6, STR)
      READ(STR,*) MAM
      CALL GETARG(7, STR)
      READ(STR,*) KSYM
      
      CALL ANGBAS(KSYM,L,M,LMAX,NANG,LAN,MAN)
      NSPS = 0
      DO i= 1, NANG
        NSPS = NSPS + 2 * NDVR + L(i)
      ENDDO
      DEALLOCATE(L, M)
      
      ALLOCATE(CK(NSPS))
      FILENAME=SYMNAME('L', MODEL,KSYM,NDVR,LMAX,INT(RADA),MAN)
      OPEN(UNIT = 1, FILE=FILENAME, FORM = 'unformatted', 
     &        ACCESS = 'direct', RECL = NSPS * 16)
      READ(1, REC = 1) CK
      CLOSE(1)
      PRINT *, SLENGTH(RADA,NSPS,NANG,CK)
      END