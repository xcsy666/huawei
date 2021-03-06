/* Script calculate the maximum temperature recorded in that particular year
*/
A = LOAD '/user/root/temp.txt' USING PigStorage(' ')AS (year:int,temperature:int);
B = GROUP A BY year;
C = FOREACH B GENERATE group,MAX(A.temperature);
STORE C INTO '/pig_example/max_temp_output';