%GLOBAL MATCHEDVAR1 MATCHEDVAR2 MATCHEDVAR3 MATCHEDVAR4 MATCHEDVAR5 MATCHEDVAR6 MATCHEDVAR7;
%GLOBAL ADDMATCHEDVAR1 ADDMATCHEDVAR2 ADDMATCHEDVAR3 ADDMATCHEDVAR4 ADDMATCHEDVAR5 ADDMATCHEDVAR6 ADDMATCHEDVAR7;

%MACRO MVAR_LIST(PREF=,SUFF=,COMMA=, OUTPUT=, INPUTLIST=);
	%LOCAL I VAR_SEL VAR_CUM INSERTCOMMA;
	%LET VAR_CUM = ;
	%IF &COMMA = YES %THEN %DO;
		%LET INSERTCOMMA = ,;
	%END;
	%ELSE %DO;
		%LET INSERTCOMMA = ;
	%END;

	%DO I = 1 %TO %SYSFUNC(COUNTW(&INPUTLIST.));
		%LET VAR_SEL = %SCAN(&INPUTLIST.,&I);
		
		%IF &SUFF. = TYPE %THEN %DO;
			%LET INSERTSUFF = DECIMAL;
		%END;
		%ELSE %DO;
			%LET INSERTSUFF = ;
		%END;

		%IF &I = 1 %THEN %DO;
			%LET VAR_CUM = &PREF.&VAR_SEL &INSERTSUFF.;
		%END;
		%ELSE %DO;
			%LET VAR_CUM = &VAR_CUM &INSERTCOMMA. &PREF.&VAR_SEL &INSERTSUFF.;
		%END;	
	%END;
	%LET &OUTPUT. = &VAR_CUM.;
%MEND MVAR_LIST;

%MVAR_LIST(PREF=SA.,SUFF=,COMMA=YES,OUTPUT=MATCHEDVAR4,INPUTLIST=&MVAR_LIST4.);
%MVAR_LIST(PREF=,SUFF= TYPE,COMMA=YES,OUTPUT=ADDMATCHEDVAR4,INPUTLIST=&MVAR_LIST4.);

%GLOBAL MATCHINGCOND1 MATCHINGCOND2 MATCHINGCOND3 MATCHINGCOND4 MATCHINGCOND5 MATCHINGCOND6 MATCHINGCOND7;
%MACRO MVAR_LIST(TABLE1=,TABLE2=,OUTPUT=,NUM=);
	%LOCAL I VAR_SEL VAR_CUM;
	%LET VAR_CUM = ;

	%DO I = 1 %TO %SYSFUNC(COUNTW(&&MVAR_LIST&NUM.));
		%LET VAR_SEL = %SCAN(&&MVAR_LIST&NUM.,&I);

		%IF &I = 1 %THEN %DO;
			%LET VAR_CUM = ON &TABLE1.&VAR_SEL = &TABLE2.&VAR_SEL;
		%END;
		%ELSE %DO;
			%LET VAR_CUM = &VAR_CUM AND &TABLE1.&VAR_SEL = &TABLE2.&VAR_SEL;
		%END;	
	%END;
	%LET &OUTPUT. = &VAR_CUM.;
%MEND MVAR_LIST;
%MVAR_LIST(TABLE1=SA.,TABLE2=SB.,OUTPUT=MATCHINGCOND4,NUM=4);


/* MATCHING */
%MACRO CC_MATCHING(ST=, END=, NAME=, TREATED_NAME=, MATCHED_TG=, NUM =,RATIO= );
%LET STTIME = %SYSFUNC(TIME()); %LET STTIME8 = %SYSFUNC(TIME(),TIME8.0);
PROC SQL; DROP TABLE SAPTMP.&NAME.; QUIT;
%DO Y = &ST. %TO &END.;
	%PUT &Y. START;
	%DO K = 1 %TO &RATIO.;

	%IF &Y. = &ST. AND &K = 1 %THEN %DO; %LET CREATE_OR_INSERT=CREATE TABLE ; %LET AS_YN=AS ; %END;
	%ELSE %DO; %LET CREATE_OR_INSERT=INSERT INTO ; %LET AS_YN=  ; %END;

	PROC SQL; connect to saphana as x1(server=x port=y user=z password=w);	
	EXECUTE(
		&CREATE_OR_INSERT. &NAME. &AS_YN.(
	
	    	SELECT &K. AS MIT, SA.*
			,CASE WHEN COALESCE(SA.CNT,0) < COALESCE(SA.CNT_MTCH,0) THEN 1 ELSE 0 END AS STRBTG
			,CASE WHEN COALESCE(SA.CNT,0) >= COALESCE(SA.CNT_MTCH,0) THEN 1 ELSE 0 END AS BTRSTG

			,SB.CID AS CID_MTCH
			,SB.MID AS MID_MTCH
			,SB.FID AS FID_MTCH
			,SB.DTH_C AS C_DTH_MTCH
			,SB.DTH_F AS F_DTH_MTCH
			,SB.DTH_M AS M_DTH_MTCH
			,SB.RN_MTCH

	   	FROM (
		    SELECT SA.*, SB.CNT_MTCH
				, CASE
					WHEN SA.CNT < SB.CNT_MTCH THEN ROUND(1 + RAND() * (SB.CNT_MTCH-1)) 
					WHEN SA.CNT >= SB.CNT_MTCH THEN ROW_NUMBER() OVER (PARTITION BY &&MATCHEDVAR&NUM.)
				END AS RN

				FROM (
				SELECT SA.*, COUNT(*) OVER (PARTITION BY &&MATCHEDVAR&NUM.) AS CNT
				FROM &TREATED_NAME. AS SA
				WHERE BYEAR_C = %NRBQUOTE('&Y.')
			) AS SA

				LEFT JOIN( 
				SELECT  &&MATCHEDVAR&NUM., COUNT(CID) AS CNT_MTCH
				FROM &MATCHED_TG. AS SA
				WHERE BYEAR_C = %NRBQUOTE('&Y.')
					AND BYEAR_M IS NOT NULL
					AND BYEAR_F IS NOT NULL
				GROUP BY &&MATCHEDVAR&NUM.
			) SB
			&&MATCHINGCOND&NUM.
		) AS SA

		LEFT JOIN (
			SELECT SA.*, ROW_NUMBER() OVER (PARTITION BY &&MATCHEDVAR&NUM. ORDER BY RAND()) AS RN_MTCH
		    FROM &MATCHED_TG. AS SA
			WHERE BYEAR_C = %NRBQUOTE('&Y.')
			AND BYEAR_M IS NOT NULL
			AND BYEAR_F IS NOT NULL
			AND (DTH_M IS NULL OR SUBSTR(DTH_M,1,4) >= STD_YYYY)
			AND (DTH_F IS NULL OR SUBSTR(DTH_F,1,4) >= STD_YYYY)
			AND (DTH_C IS NULL OR SUBSTR(DTH_C,1,4) >= STD_YYYY)
		) AS SB
		&&MATCHINGCOND&NUM.
		AND SA.RN = SB.RN_MTCH

		/* SQL END */
	)) BY X1; DISCONNECT FROM X1; QUIT;
	%PUT MATCHING VAR SET = &NUM. , BIRTH YEAR = &Y., ITERATION : &K. / &RATIO. DONE;
	%END K;
	%TICTOCINS(NAME=CC_TICTOC&DATE., LABEL=STEP6 MATCHING &K. DONE);
%END YMSERIAL;