/*******************************************************************************************
 Project Title: NHANES Breast Cancer Analysis (2017–2020)
 Author      : Nuzhat Faizah
 Platform    : SAS Studio on Demand
 Description : This end-to-end SAS project explores associations between various
                demographic, behavioural, and clinical predictors and self-reported
                breast cancer diagnosis among U.S. women using NHANES 2017–March 2020 data.

                Workflow includes:
                - Importing and subsetting multiple NHANES .xpt files (DEMOGRAPHIC, EXAM, LAB, etc.)
                - Creating and labelling derived variables
                - Merging datasets into a master analytic file (females only)
                - Conducting bivariate and multivariate analysis using survey procedures
                - Fitting logistic regression models including interaction effects
                - Producing descriptive and inferential outputs for interpretation

                All analyses account for NHANES’ complex survey design using weights,
                strata, and clustering variables to ensure nationally representative results.

                Last but not least, this is my first humble effort to execute an entire
                project using SAS Studio on Demand, including logistic regression modelling.
                I know I still have much to learn, so please feel free to leave any 
                constructive feedback. Thank you!

 Created      : [30th April 2025]
 Last Updated : [25th June 2025]
*******************************************************************************************/

/****************************************************/
/* DEFINING THE INDEPENDENT and DEPENDENT VARIABLES
/****************************************************/

/*------------ 1. DEMOGRAPHIC DATA ------------*/

/* Loading the demographic data and filtering for SEQN and the following list:
i. Age(RIDAGEYR), 
ii. Gender(RIAGENDR), 
iii. Race/Ethnicity(RIDRETH3), 
iv. Education Level(DMDEDUC2), and 
v. Family Income-to_Poverty Ratio (INDFMPIR)  */;

/* Importing the demographic dataset */
libname nhanes xport "/home/u63979661/AHS/P_DEMO_2017-2020.xpt";
data demo;
  set nhanes.P_DEMO;
run;

/* Creating a subset with selected demographic and survey design variables; filtering for females only */
data demo_subset;
  set demo;
  keep SEQN RIDAGEYR RIAGENDR RIDRETH3 DMDEDUC2 INDFMPIR 
       WTMECPRP SDMVSTRA SDMVPSU;  /* Including survey weight, strata, and cluster */
  if RIAGENDR = 2; /* Filtering for female participants */
run;

*/ Extra note for justification: The MEC examination weights should be used for analyses that include examination data (including the MEC interview and some laboratory data).”
— Sample Design, Estimation, and Analytic Guidelines, 2017-March 2020 Prepandemic file. 
Hence I am using 'WTMECPRP - Full sample MEC exam weight' instead of 'WTINTPRP - Full sample interview weight'. */

/* Verifying structure and variables in the demographic subset */;
proc contents data=demo_subset;
run;

proc sql;
  describe table demo_subset;
quit;

proc print data=demo_subset(obs=15);
run;

/*------------ 2. EXAMINATION DATA ------------*/

/* Importing the body measures dataset */
libname nhanes xport "/home/u63979661/AHS/P_BMX_2017-2020.xpt";
data bmi;
  set nhanes.P_BMX;
run;

/* Creating a subset with SEQN and BMI */
data bmi_subset;
  set bmi;
  keep SEQN BMXBMI;
run;

/* Verifying structure and variables in the BMI subset */
proc contents data=bmi_subset;
run;

proc sql;
  describe table bmi_subset;
quit;

proc print data=bmi_subset(obs=15);
run;

/*------------ 3. LABORATORY DATA ------------*/

/* (i) Importing the total cholesterol dataset */
libname nhanes xport "/home/u63979661/AHS/P_TCHOL_2017-2020.xpt";
data chol;
  set nhanes.P_TCHOL;
run;

/* Creating a subset with SEQN and total cholesterol */
data chol_subset;
  set chol;
  keep SEQN LBXTC;
run;

/* Verifying structure of cholesterol subset */
proc contents data=chol_subset;
run;

proc sql;
  describe table chol_subset;
quit;

proc print data=chol_subset(obs=15);
run;

/* (ii) Importing the insulin dataset */
libname nhanes xport "/home/u63979661/AHS/P_INS_2017-2020.xpt";
data insulin;
  set nhanes.P_INS;
run;

/* Creating a subset with SEQN, insulin, and fasting weight */
data insulin_subset;
  set insulin;
  keep SEQN LBXIN WTSAFPRP;
  label LBXIN = "Insulin (uU/mL)";
run;

/* Verifying structure of insulin subset */
proc contents data=insulin_subset;
run;

proc sql;
  describe table insulin_subset;
quit;

proc print data=insulin_subset(obs=15);
run;

/* (iii) Importing the high-sensitivity C-reactive protein dataset */
libname nhanes xport "/home/u63979661/AHS/P_HSCRP_2017-2020.xpt";
data crp;
  set nhanes.P_HSCRP;
run;

/* Creating a subset with SEQN and hs-CRP, and renaming for clarity */
data crp_subset;
  set crp;
  crp = LBXHSCRP;
  label crp = "High-Sensitivity C-Reactive Protein (mg/L)";
  keep SEQN crp;
run;

/* Summarizing and verifying structure of CRP subset */
proc means data=crp_subset n mean std min max;
  var crp;
run;

proc contents data=crp_subset;
run;

proc sql;
  describe table crp_subset;
quit;

proc print data=crp_subset(obs=15);
run;

/*------------ 4. QUESTIONNAIRE DATA ------------*/

/* Importing P_MCQ.xpt and creating both outcome + independent variables */
libname nhanes xport "/home/u63979661/AHS/P_MCQ_2017-2020.xpt";

data mcq_final;
  set nhanes.P_MCQ;

  /* Checking if the participant was ever diagnosed with cancer */
  if MCQ220 = 1 then had_cancer = 1;
  else if MCQ220 in (2, 7, 9) then had_cancer = 0;
  else had_cancer = .;

  /* Creating breast cancer outcome ONLY for those diagnosed with cancer */
  if had_cancer = 1 then do;
    if MCQ230A = 14 then breast_cancer_dx = 1;
    else if not missing(MCQ230A) then breast_cancer_dx = 0;
    else breast_cancer_dx = .;
  end;
  else breast_cancer_dx = 0;

  /* Recoding thyroid disorder */
  if MCQ160M = 1 then thyroid_dx = 1;
  else if MCQ160M = 2 then thyroid_dx = 0;
  else thyroid_dx = .;

  /* Recoding family history of heart attack */
  if MCQ300A = 1 then heart_attack_family = 1;
  else if MCQ300A = 2 then heart_attack_family = 0;
  else heart_attack_family = .;

  /* Recoding family history of diabetes */
  if MCQ300C = 1 then diabetes_family = 1;
  else if MCQ300C = 2 then diabetes_family = 0;
  else diabetes_family = .;

  label 
    breast_cancer_dx     = "Breast Cancer Diagnosis (1=Yes, 0=No)"
    thyroid_dx           = "Thyroid Disorder (1=Yes, 0=No)"
    heart_attack_family  = "Family History of Heart Attack (1=Yes, 0=No)"
    diabetes_family      = "Family History of Diabetes (1=Yes, 0=No)";

  keep SEQN breast_cancer_dx thyroid_dx heart_attack_family diabetes_family;
run;

/* Checking the metadata and confirming if the codes ran successfully */
proc contents data=mcq_final;  
run;

proc print data=mcq_final (obs=15);
run;

/* (ii) Loading the Physical Activity data and creating a binary indicator for vigorous work activity */
libname nhanes xport "/home/u63979661/AHS/P_PAQ_2017-2020.xpt";

data paq_subset;
  set nhanes.P_PAQ(keep=SEQN PAQ605);

  /* Recoding vigorous work activity: 1 = Yes, 0 = No; excluding Refused/Don't know */
  if PAQ605 = 1 then vigorous_work = 1;
  else if PAQ605 = 2 then vigorous_work = 0;
  else vigorous_work = .;

  label vigorous_work = "Vigorous Work Activity (1=Yes, 0=No)";
run;

/* Frequency table to check the recoded variable */
proc freq data=paq_subset;
  tables vigorous_work / missing;
run;

/* Describing table structure */
proc sql;
  describe table paq_subset;
quit;

/* Printing first 50 observations */
proc print data=paq_subset(obs=50);
  title "First 50 Observations of paq_subset Dataset";
run;
title;

/* (iii) Loading the Alcohol Use data and creating a cleaned variable for daily average alcohol intake */
libname nhanes xport "/home/u63979661/AHS/P_ALQ_2017-2020.xpt";

data alcohol_subset;
  set nhanes.P_ALQ(keep=SEQN ALQ130);

  /* Recoding average alcohol use per day; setting refused (777) and don't know (999) to missing */
  if ALQ130 in (777, 999) then alcohol_avg = .;
  else alcohol_avg = ALQ130;

  label alcohol_avg = "Avg # Alcoholic Drinks/Day (Past 12 Months)";
run;

/* Displaying summary statistics to confirm values */
proc means data=alcohol_subset n mean std min max;
  var alcohol_avg;
run;

/* Generating frequency distribution including missing */
proc freq data=alcohol_subset;
  tables alcohol_avg / missing;
run;

/* Describing structure of the subset */
proc sql;
  describe table alcohol_subset;
quit;

/* Previewing first 50 observations */
proc print data=alcohol_subset(obs=50);
  title "First 50 Observations of alcohol_subset Dataset";
run;
title;

/* (iv) Importing the data for Age at First Menstrual Period and Female Hormone Use */
libname nhanes xport "/home/u63979661/AHS/P_RHQ_2017-2020.xpt";
data rhq;
  set nhanes.P_RHQ(keep=SEQN RHQ010 RHQ540);
run;

/* Creating a cleaned subset with recoding and variable labels */
data rhq_subset;
  set rhq;

  /* Recoding age at first menstrual period: setting invalid responses as missing */
  if RHQ010 in (0, 777, 999, .) then age_menarche = .;
  else age_menarche = RHQ010;

  /* Recoding hormone use: 1 = Yes, 0 = No, other responses set to missing */
  if RHQ540 = 1 then hormone_use = 1;
  else if RHQ540 = 2 then hormone_use = 0;
  else hormone_use = .;

  label 
    age_menarche = "Age at First Menstrual Period (Years)"
    hormone_use = "Ever Used Female Hormones (1=Yes, 0=No)";
run;

/* Descriptive stats for age at menarche */
title "Table: Summary Statistics for Age at First Menstrual Period";
proc means data=rhq_subset n mean std min max;
  var age_menarche;
run;
title;

/* Frequency table for female hormone use */
title "Table: Frequency of Female Hormone Use";
proc freq data=rhq_subset;
  tables hormone_use / missing;
run;
title;

/* Verifying table structure */
proc sql;
  describe table rhq_subset;
quit;

proc print data=rhq_subset(obs=50);
run;

/* (v) Importing the data for SEQN and if the respondent Smoked at least 100 cigarettes in life */
libname nhanes xport "/home/u63979661/AHS/P_SMQ_2017-2020.xpt";

data smoking_subset;
  set nhanes.P_SMQ(keep=SEQN SMQ020);
  if SMQ020 = 1 then ever_smoked = 1;  /* Recoding: 1 = Yes, 0 = No, all others = missing */
  else if SMQ020 = 2 then ever_smoked = 0;
  else ever_smoked = .;
  label ever_smoked = "Smoked at Least 100 Cigarettes in Life (1=Yes, 0=No)";
run;

/* Frequency check */
proc freq data=smoking_subset;
  tables ever_smoked / missing;
run;

proc sql;
  describe table smoking_subset;
quit;

/*************************************/
/* MERGING ALL CLEANED DATASETS – TRIAL 3 */
/*************************************/

/* Sorting all datasets by SEQN */
proc sort data=demo_subset;         
by SEQN; 
run;
proc sort data=mcq_final;           
by SEQN; 
run;
proc sort data=bmi_subset;          
by SEQN; 
run;
proc sort data=chol_subset;         
by SEQN; 
run;
proc sort data=insulin_subset;      
by SEQN; 
run;
proc sort data=crp_subset;          
by SEQN; 
run;
proc sort data=paq_subset;          
by SEQN; 
run;
proc sort data=alcohol_subset;      
by SEQN; 
run;
proc sort data=rhq_subset;          
by SEQN; 
run;
proc sort data=smoking_subset;      
by SEQN; 
run;

/* Merging all datasets into a master dataset */
data analysis_trial3;
  merge
    demo_subset         (in=a)   /* Keeps females only */
    mcq_final           (in=b)   /* Ensures breast cancer variable present */
    bmi_subset
    chol_subset
    insulin_subset
    crp_subset
    paq_subset
    alcohol_subset
    rhq_subset
    smoking_subset;
  by SEQN;

  /* Keeping only female participants with breast cancer info */
  if a and b;

  label 
    analysis_trial3 = "NHANES 2017–March 2020 Breast Cancer Trial 3 Dataset (Females Only)";
run;

/* Filtering for complete cases (no missing in predictors or outcome) */
data analysis_trial3_complete;
set analysis_trial3;

if breast_cancer_dx in (0,1) and
not missing(BMXBMI) and
not missing(LBXTC) and
not missing(LBXIN) and
not missing(WTSAFPRP) and
not missing(crp) and
not missing(thyroid_dx) and
not missing(heart_attack_family) and
not missing(diabetes_family) and
not missing(vigorous_work) and
not missing(alcohol_avg) and
not missing(age_menarche) and
not missing(hormone_use) and
not missing(ever_smoked) and
not missing(RIDAGEYR) and
not missing(RIDRETH3) and
not missing(DMDEDUC2) and
not missing(INDFMPIR);
run;

/* Checking for duplicates */
proc freq data=analysis_trial3_complete noprint;
tables SEQN / out=seqn_freq;
run;

proc sql;
select count(*) as num_duplicates
from seqn_freq
where count > 1;
quit;

/* Previewing final dataset */
proc contents data=analysis_trial3_complete;
run;

proc print data=analysis_trial3_complete (obs=15);
run;

/****************************************************/
/* BIVARIATE STATISTICAL ANALYSIS
/****************************************************/

/* (i) Bivariate Associations Using Survey-Adjusted Chi-Square Tests: Pairwaise combinations of binary variables */

/* 1. Thyroid disorder */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * thyroid_dx / chisq;
run;

/* 2. Family history of heart attack */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * heart_attack_family / chisq;
run;

/* 3. Family history of diabetes */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * diabetes_family / chisq;
run;

/* 4. Vigorous physical activity at work */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * vigorous_work / chisq;
run;

/* 5. Smoked at least 100 cigarettes in life */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * ever_smoked / chisq;
run;

/* 6. Ever used female hormones */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * hormone_use / chisq;
run;

/* Bivariate Associations Between Breast Cancer Diagnosis and Multilevel Categorical Predictors Using Rao–Scott Chi-Square Tests */

/* 1. Race/Ethnicity */
data analysis_trial3_complete;
  set analysis_trial3_complete;

  /* Collapsing race/ethnicity into 3 categories */
  if RIDRETH3 = 3 then race3 = 1;               /* White */
  else if RIDRETH3 = 4 then race3 = 2;          /* Black */
  else if RIDRETH3 in (1, 2, 6, 7) then race3 = 3; /* Hispanic/Other */
  else race3 = .;                               /* Missing/refused */

  label race3 = "Collapsed Race/Ethnicity (1=White, 2=Black, 3=Hispanic/Other)";
run;

proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * race3 / chisq;
run;

/* 2. Education Level */
data analysis_trial3_complete;
  set analysis_trial3_complete;

  /* Collapsing education into 3 groups */
  if DMDEDUC2 in (1, 2) then educ3 = 1;           /* Less than high school */
  else if DMDEDUC2 = 3 then educ3 = 2;            /* High school graduate */
  else if DMDEDUC2 in (4, 5) then educ3 = 3;      /* College or higher */
  else educ3 = .;                                 /* Missing, refused, don't know */

  label educ3 = "Collapsed Education Level (1=Low, 2=HS Grad, 3=College+)";
run;

proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables breast_cancer_dx * educ3 / chisq;
run;

/* Bivariate analysis for for all the continuous predictors: */;

proc surveymeans data=analysis_trial3_complete mean stderr;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  domain breast_cancer_dx;
  var RIDAGEYR INDFMPIR BMXBMI LBXTC LBXIN WTSAFPRP crp alcohol_avg age_menarche;
run;

/* Testing Mean Differences in Continuous Variables by Breast Cancer Diagnosis Using Survey-Adjusted Linear Regression (PROC SURVEYREG) */

/* 1. Mean Age Comparison by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model RIDAGEYR = breast_cancer_dx;
run;

/* 2. Comparison of Income-to-Poverty Ratio by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model INDFMPIR = breast_cancer_dx;
run;

/* 	3. Body Mass Index Differences by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model BMXBMI = breast_cancer_dx;
run;

/* 4. Total Cholesterol Level Comparison by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */ 
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model LBXTC = breast_cancer_dx;
run;

/* 	5. Insulin Level Differences by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model LBXIN = breast_cancer_dx;
run;

/* 	6. Fasting Subsample Weight Comparison by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model WTSAFPRP = breast_cancer_dx;
run;

/* 7. C-Reactive Protein Level Comparison by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model crp = breast_cancer_dx;
run;

/* 8. Average Daily Alcohol Intake by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model alcohol_avg = breast_cancer_dx;
run;

/* 	9. Age at Menarche Differences by Breast Cancer Diagnosis (Survey-Adjusted Linear Regression) */
proc surveyreg data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  class breast_cancer_dx;
  model age_menarche = breast_cancer_dx;
run;

/****************************************************/
/* DESCRIPTIVE STATISTICS
/****************************************************/

/* Descriptive statistics for categorical variables */
proc surveyfreq data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  tables 
    breast_cancer_dx
    thyroid_dx 
    heart_attack_family 
    diabetes_family 
    vigorous_work 
    ever_smoked 
    hormone_use 
    race3 
    educ3;
run;

/* Descriptive statistics for continuous variables */
proc surveymeans data=analysis_trial3_complete mean stderr min max;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;
  var 
    RIDAGEYR 
    INDFMPIR 
    BMXBMI 
    LBXTC 
    LBXIN 
    crp 
    alcohol_avg 
    age_menarche;
run;


/****************************************************/
/* MULTIVARIATE STATISTICAL ANALYSIS
/****************************************************/

/* Creating the full model first using Survey-Adjusted Logistic Regression */

proc surveylogistic data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;

  /* Specifying all categorical variables here */
  class 
    thyroid_dx 
    heart_attack_family 
    diabetes_family 
    vigorous_work 
    ever_smoked 
    hormone_use 
    race3  /* RIDRETH3 was collapsed to race3 to make the variable analyzable */
    educ3  /* DMDEDUC2 was collapsed to educ3 to make the variable analyzable */
    / param=ref ref=first;

* Logistic regression model with all predictors;
  model breast_cancer_dx(event='1') = 
    thyroid_dx
    heart_attack_family
    diabetes_family
    vigorous_work
    ever_smoked
    hormone_use
    race3
    educ3
    RIDAGEYR
    INDFMPIR
    BMXBMI
    LBXTC
    LBXIN
    WTSAFPRP
    crp
    alcohol_avg
    age_menarche;
run;

/* Creating a reduced model using only the statistically signifiant predictors, a part of variable selection techniques */

proc surveylogistic data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;

  /* Only categorical variable here is race3 */
  class race3 / param=ref ref=first;

  model breast_cancer_dx(event='1') = 
    RIDAGEYR
    race3
    WTSAFPRP;
run;

/* Creating an interaction model using only the statistically signifiant predictors */ 

proc surveylogistic data=analysis_trial3_complete;
  strata SDMVSTRA;
  cluster SDMVPSU;
  weight WTMECPRP;

  class race3 / param=ref ref=first;

  model breast_cancer_dx(event='1') = 
    RIDAGEYR
    race3
    RIDAGEYR*race3;
run;

/******* THE END *******/
















