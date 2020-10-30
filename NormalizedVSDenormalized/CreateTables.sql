-- ----------------------------------------
-- import a public set of names
-- ----------------------------------------
CREATE OR REPLACE TABLE testNormalisedDeNormalised.names
(
  firstname STRING,
  gender STRING
);
INSERT INTO testNormalisedDeNormalised.names
SELECT distinct name as firstname, lower(gender) FROM `fh-bigquery.popular_names.usa_summary_1880_2015` limit 100000
;


-- ----------------------------------------
-- create reference/dimension tables + data
-- ----------------------------------------

-- ----------------------------------------
-- gender
-- ----------------------------------------

CREATE OR REPLACE TABLE testNormalisedDeNormalised.gender
(
  genderId INT64,
  genderCode STRING,
  genderName STRING
);

insert into testNormalisedDeNormalised.gender (genderId, genderCode, genderName)
SELECT *
FROM 
UNNEST([
  (1,'m', 'male'),
  (2,'f', 'female')
]);

-- ----------------------------------------
-- marital status
-- ----------------------------------------
CREATE OR REPLACE TABLE testNormalisedDeNormalised.maritalStatus
(
  maritalStatusId INT64,
  maritalStatusCode STRING,
  maritalStatus STRING
);

insert into testNormalisedDeNormalised.maritalStatus
SELECT *
FROM UNNEST([
  (1,'married', 'married'), 
  (2,'single', 'single'),
  (3,'divorced',''),
  (4, 'widowed','')
]);

-- ----------------------------------------
-- employment status
-- ----------------------------------------
CREATE OR REPLACE TABLE testNormalisedDeNormalised.employmentStatus
(
  employmentStatusId INT64,
  employmentStatusCode STRING,
  employmentStatusName STRING
);

insert into testNormalisedDeNormalised.employmentStatus
SELECT *
FROM UNNEST([
  (1,'unemployed', 'unemployed'), 
  (2,'self-employed', 'self-employed'),
  (3,'full time','full time'),
  (4, 'student','student')
]);


-- ----------------------------------------
-- age range
-- ----------------------------------------
CREATE OR REPLACE TABLE testNormalisedDeNormalised.ageRange
(
  ageRangeId INT64,
  ageRangeCode STRING,
  ageRangeName STRING,
  ageRangeStart int64,
  ageRangeEnd int64
);

insert into testNormalisedDeNormalised.ageRange
SELECT *
FROM UNNEST([
  (1,'0-9',  '0 to 9',0,9),
  (2,'10-19',  '10 to 19',10,19),
  (3,'20-29',  '20 to 29',20,29),
  (4,'30-39',  '30 to 39',30,39),
  (5,'40-49',  '40 to 49',40,49),
  (6,'50-59',  '50 to 59',50,59),
  (7,'60-69',  '60 to 69',60,69),
  (8,'70-79',  '70 to 79',70,79),
  (9,'80-89',  '80 to 89',80,89),
  (10,'90-999',  '90 to 999',90,999)
]);


-- ----------------------------------------
-- create the 2 different empty tables
-- ----------------------------------------

CREATE OR REPLACE TABLE testNormalisedDeNormalised.personFlat
(
  personID STRING,
  firstname STRING,
  lastname STRING,
  dateOfBirth DATE,
  genderCode STRING,
  genderName STRING,
  ageRangeCode STRING,
  ageRangeName STRING,
  ageRangeStart int64,
  ageRangeEnd int64,  
  employmentStatusCode STRING,
  employmentStatusName STRING,
  maritalStatusCode STRING,
  maritalStatus STRING  
);

CREATE OR REPLACE TABLE testNormalisedDeNormalised.personNorm
(
  personID STRING,
  firstname STRING,
  lastname STRING,
  dateOfBirth DATE,
  genderId INT64,
  ageRangeId INT64,
  employmentStatusId INT64,
  maritalStatusId INT64,
);

-- ----------------------------------------
-- creating the full person record in memory
-- ----------------------------------------

create temp table  personRecord as (
SELECT 
a.firstname, 
b.firstname as lastname, 
g.*
DATE '1921-01-01' + cast(RAND()*30000 AS INT64) as DateOfBirth ,
mar.*,
empl.*
FROM testNormalisedDeNormalised.names a 
inner join testNormalisedDeNormalised.gender g on g.genderCode = a.gender
cross join testNormalisedDeNormalised.names b 
cross join testNormalisedDeNormalised.maritalStatus mar
cross join testNormalisedDeNormalised.employmentStatus empl
where rand() < 2000000 / 10000000000  
limit 2000000 -- 2mil records
);
create temp table personTemp as (
select  GENERATE_UUID() as personID, * from personRecord p
inner join testNormalisedDeNormalised.ageRange age on date_diff(current_date(), p.DateOfBirth, year) between age.ageRangeStart and age.ageRangeEnd
);

create or replace table testNormalisedDeNormalised.personFull as (select * from personTemp);


select * from testNormalisedDeNormalised.personFull limit 200;



insert into testNormalisedDeNormalised.personNorm (
select 
  personID,
  firstname,
  lastname,
  dateOfBirth,
  genderId,
  ageRangeId,
  employmentStatusId,
  maritalStatusId
from testNormalisedDeNormalised.personFull);

select * from testNormalisedDeNormalised.personNorm limit 200;

insert into testNormalisedDeNormalised.personFlat (
select 
  personID ,
  firstname ,
  lastname ,
  dateOfBirth ,
  genderCode ,
  genderName ,
  ageRangeCode ,
  ageRangeName ,
  ageRangeStart ,
  ageRangeEnd ,  
  employmentStatusCode ,
  employmentStatusName ,
  maritalStatusCode ,
  maritalStatus   
from testNormalisedDeNormalised.personFull);

select * from testNormalisedDeNormalised.personFlat limit 200;

-- ------------------------------
-- sample queries
-- ------------------------------


select count(*) from testNormalisedDeNormalised.personFlat
where genderCode = 'm' 
and ageRangeCode = '20-29'
and employmentStatusCode = 'unemployed';
-- prcessing data: 667.4 MB


select count(*) 
from testNormalisedDeNormalised.personNorm a
inner join testNormalisedDeNormalised.gender g on a.genderId = g.genderId 
inner join testNormalisedDeNormalised.ageRange ag on a.ageRangeId = ag.ageRangeId
inner join testNormalisedDeNormalised.employmentStatus e on a.employmentStatusId = e.employmentStatusId
where g.genderCode = 'm' 
and ag.ageRangeCode = '20-29'
and e.employmentStatusCode = 'unemployed'
-- processing data : 732.3 MB

