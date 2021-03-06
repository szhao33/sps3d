C***********************************************************************
      PROGRAM MAIN
C
C  SPS expansion for the R problem with L.GE.0 [PRA 75, 062704 (2007)]
C  Partial-wave scattering characteristics
C
C***********************************************************************
      USE ANGSYM
      USE OMP_LIB
      IMPLICIT REAL*8 (A,B,D-H,O-Z)
      IMPLICIT COMPLEX*16 (C)
      PARAMETER(PI=3.141592653589793238462643D0)
      PARAMETER(LANMAX=28)
      ALLOCATABLE CK(:),CE(:),CPHI(:,:),CVEC(:,:),CS(:,:), CEL(:)
      ALLOCATABLE L(:),M(:),PIR(:)
      ALLOCATABLE KSYMA(:),LANA(:),MANA(:),MULTIP(:)
      ALLOCATABLE DELTA(:),CDETP(:), CDELTA(:)
      NAMELIST /INF3D/MODEL,RADA,NDVR,KPOL,LMAX,LAN,MAN,KSYM,NTET,NPHI,
     & 		KEYA,AMIN,AMAX,NUMA
      COMMON /POT_C/MODEL
      CHARACTER(LEN=20) :: DELTANAME
      LOGICAL :: INPUT
C
C  Input parameters
C
      OPEN(1,file='inf')
      READ(1,INF3D)
      CLOSE(1)
      IF(LAN.GT.LANMAX) STOP ' *** LANMAX ERROR'
      
      SELECT CASE(KSYM)
      CASE (0)
	NSYM = 1
	ALLOCATE(KSYMA(NSYM))
	KSYMA(1) = KSYM
      CASE (90,-90)
	NSYM = 2
	ALLOCATE (KSYMA(NSYM))
	KSYMA(1) = 90
	KSYMA(2) = -90
      CASE (1)
	NSYM = 2 * LMAX + 1
	ALLOCATE (KSYMA(NSYM))
	DO i = 1, NSYM
	  KSYMA(i) = KSYM
	ENDDO
      CASE (2)
	NSYM = LMAX + 1
	ALLOCATE (KSYMA(NSYM))
	KSYMA = 2
      CASE (10,20,30,40,50,60,70,80)
	NSYM = 8
	ALLOCATE (KSYMA(NSYM))
	DO i = 1, 8
	  KSYMA(i) = i * 10
	ENDDO
      END SELECT
      ALLOCATE(LANA(NSYM),MANA(NSYM),MULTIP(NSYM))
      SELECT CASE(KSYM)
      CASE (2)
	DO i = 1, NSYM
	  LANA(i) = i - 1
	  MULTIP(i) = 2 * i - 1
	  MANA(i) = 0
	ENDDO
      CASE (-90, 0, 10,20,30,40,50,60,70,80, 90)
	DO i = 1, NSYM
	  MULTIP(i) = 1
	  LANA(i) = LAN
	  MANA(i) = MAN
	ENDDO
      CASE (1)
	DO i = 1, NSYM
	  MULTIP(i) = 1
	  LANA(i) = LAN
	  MANA(i) = -LMAX - 1 + i
	ENDDO
      END SELECT
      
      IF (CONSOLE_INPUT(EMAX, NS)) INPUT = .TRUE.

      ALLOCATE(CDELTA(NS), DELTA(NS), CDETP(NS))
      CDELTA = 1.D0
      DELTA = 0.D0
      CDETP = 1.D0

      ALLOCATE(PIR(NDVR))
      CALL OMP_SET_NUM_THREADS( 2 )
!$OMP PARALLEL DO DEFAULT(PRIVATE) REDUCTION(+:DELTA) REDUCTION(
!$OMP& *:CDELTA, CDETP) SHARED(KSYMA, LANA, MANA, MULTIP, EMAX,NS,
!$OMP& LMAX, NDVR, RADA, NTET, NPHI, INPUT)
      DO i = 1, NSYM
	NSPS = 0
	NANG = 0
	CALL ANGBAS(KSYMA(i),L,M,LMAX,NANG,LANA(i),MANA(i))
	PRINT *, KSYMA(i), LANA(i), MANA(i), i
	DO j= 1, NANG
	  NSPS = NSPS + 2 * NDVR + L(j)
	ENDDO
	ALLOCATE(CK(NSPS),CE(NSPS),CVEC(NDVR*NANG,NSPS))
	ALLOCATE(CPHI(NANG,NSPS))
	CALL SPS3D(LMAX,NANG,L,M,RADA,NDVR,NTET,NPHI,PIR,CK,CE
     &	    	,CVEC,CPHI,NB,NA,NOI) 
	IF (INPUT) THEN
	  ALLOCATE (CS(NANG, NANG), CEL(NANG))
	  WRITE(DELTANAME, "(A5,I0)"), "delta", KSYMA(i)
	  OPEN(1, FILE=DELTANAME)
	  DO k = 1, NS
	    CAK =  DBLE(k) * EMAX / NS
	    CALL SSUM3D(L,RADA,NSPS,NANG,CK,CPHI,CAK,CS)
	    CALL CDETS(CS,CEL,CDET,NANG)

	    CDELTA(k) = CDELTA(k) * CDET
	    DELTA(k) = DELTA(k) + MULTIP(i)*AIMAG(CDLOG(CDET)) / 2.D0
	    CALL SPRO(RADA,NSPS,CK,CAK,CDETTP)
	    CTMP = (CDETTP * CDEXP(-(0.D0,2.D0)*CAK*RADA*(NANG-1)))
     &			**MULTIP(i)	    
	    CDETP(k) = CDETP(k) * CTMP
	    WRITE(1, "(E19.12,1X)", ADVANCE="NO") DBLE(k)*EMAX/DBLE(NS)
	    WRITE(1, "(E19.12,1X)", ADVANCE="NO") AIMAG(CDLOG(CTMP))/2.D0
	    DO n = 1, NANG
	      WRITE(1, "(E19.12,1X)", ADVANCE="NO") CEL(n)
	    ENDDO
	    WRITE(1, *)
	  ENDDO
	  CLOSE(1)
	  DEALLOCATE(CS, CEL)
	ENDIF
	DEALLOCATE(L, M,CK,CE,CVEC,CPHI)
      ENDDO
!$OMP END PARALLEL DO

      IF (INPUT) THEN
	OPEN(2, FILE='delta')
	PREVDEL = 0.0
	OFFSET = 0.0
	EPS = 1
	DO k = 1, NS
	  DEL = AIMAG(CDLOG(CDETP(k)))/2.D0 + OFFSET
	  IF (DEL - PREVDEL .GT. (PI - EPS)) THEN
	    OFFSET = OFFSET - PI
	    DEL = DEL - PI
	  ENDIF
	  IF (PREVDEL - DEL .GT. (PI - EPS)) THEN
	    OFFSET = OFFSET + PI
	    DEL = DEL + PI
	  ENDIF
	  PREVDEL = DEL
	  WRITE(2, "(E19.12,1X,E19.12,1X,E19.12)")
     &	DBLE(k)*EMAX/DBLE(NS), DELTA(k), DEL
	ENDDO
	DEALLOCATE(DELTA, CDETP, CDELTA)
	CLOSE(2)
      ENDIF

      
      
c      IF (.NOT. UCHECK(CS,NANG)) PRINT *, "UNITARITY PROBLEM"

C  END
C      DEALLOCATE(PIR,CPHI,CS,CEL)
 70   FORMAT(' ground state energy = ',E19.12)
 76   FORMAT(3(E19.12,1X))
 77   FORMAT(4(E19.12,1X))
 
      CONTAINS 
        FUNCTION UCHECK(CS, NANG)
          LOGICAL UCHECK
          DIMENSION CS(NANG, NANG)


          UCHECK = .FALSE.
          DO i = 1, NANG
            DO j = 1, NANG
              CTMP = 0.D0
              DO k = 1, NANG
                CTMP = CTMP + CS(i,k) * DCONJG(CS(j,k))
              ENDDO
              IF (i.EQ.j) CTMP = CTMP - 1.D0
              IF (CDABS(CTMP) .GT. 1.D-10) THEN
                PRINT *, "NONUNITARY S MATRIX", i, j, CTMP
                RETURN 
              ENDIF
            ENDDO
          ENDDO
          UCHECK = .TRUE.
          RETURN 
        END FUNCTION
        
        FUNCTION CONSOLE_INPUT(EMAX, NS)
	  LOGICAL CONSOLE_INPUT
	  CHARACTER(LEN=20) :: STR
	  
	  CONSOLE_INPUT = .FALSE.
	  IF (IARGC() .EQ. 0) RETURN
	  CALL GETARG(1, STR)
	  READ(STR,*) EMAX
	  CALL GETARG(2, STR)
	  READ(STR,*) NS
	  CONSOLE_INPUT = .TRUE.
	  RETURN
        END FUNCTION
        END PROGRAM