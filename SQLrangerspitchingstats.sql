SELECT *
FROM RangersPitch.dbo.LastPitchRangers

SELECT *
FROM RangersPitch.Dbo.RangersPitchingStats


--AVG PITCHES ANALYSIS

--Avg Pitches Per At Bat

SELECT AVG(1.00 * pitch_number) AvgNumofPitchesPeratBat
From RangersPitch.dbo.LastPitchRangers

--AVG Pitches Per at bat home vs away 

SELECT 
	'Home' TypeofGame,
	AVG(1.00 * pitch_number) AvgNumofPitchesPerAtBat
From RangersPitch.dbo.LastPitchRangers
Where home_team = 'TEX'
UNION
SELECT
	'Away' TypeofGame,
	AVG(1.00 * pitch_number) AvgNumofPitchesPeratBat
From RangersPitch.dbo.LastPitchRangers
Where away_team = 'TEX'

--AVG Pitches Per At Bat Lefty vs Righty 

SELECT 
	AVG(Case When batter_position = 'L' Then 1.00 * Pitch_number end) LeftyatBats,
	AVG(Case When batter_position = 'R' Then 1.00 * Pitch_number end) RightyatBats
From RangersPitch.dbo.LastPitchRangers

-- AVG Pitches per at bat Left vs Right Pitcher 

SELECT DISTINCT
	home_team,
	Pitcher_position,
	AVG(1.00 * Pitch_number) OVER (Partition by home_team, Pitcher_position) 'average'
FROM RangersPitch.dbo.LastPitchRangers
Where away_team = 'TEX'


-- Top 3 most common pitch for at bat 1 through 10, and totals

with totalpitchsequence as (
	SELECT DISTINCT
		Player_name,
		Pitch_name,
		Pitch_number,
		count(pitch_name) OVER (partition by Player_name, Pitch_name, Pitch_number) PitchFrequency
	FROM RangersPitch.dbo.LastPitchRangers
	Where Pitch_number < 11
),
pitchfrequencyrankquery as (

SELECT *,
	rank() OVER (Partition by Pitch_number order by PitchFrequency desc) PitchFrequencyRanking
FROM totalpitchsequence
)
SELECT *
FROM pitchfrequencyrankquery
Order by player_name

-- AVG Pitches per at bat per pitcher with 20+ innings

SELECT 
	RPS.Name,
	AVG(1.0 * Pitch_number) AVGPitches
FROM RangersPitch.dbo.LastPitchRangers LPR
JOIN RangersPitch.Dbo.RangersPitchingstats RPS ON RPS.pitcher_id = LPR.pitcher
WHERE IP >= 20
group by RPS.Name
order by AVG(1.00 * Pitch_number)DESC


-- LAST PITCH ANALYSIS

--Count of the last pitches thrown

SELECT 
pitch_name, 
count(*) timesthrown
FROM RangersPitch.dbo.LastPitchRangers
group by pitch_name
order by count(*) DESC

-- Count of the different last pitches fastball/offspeed

SELECT
	sum(case when pitch_name in ('4-Seam Fastball', 'Cutter', 'Split-Finger') then 1 else 0 end) Fastball,
	sum(case when pitch_name NOT in ('4-Seam Fastball', 'Cutter', 'Split-Finger') then 1 else 0 end) Offspeed
FROM RangersPitch.dbo.LastPitchRangers

-- Percentage of different last pitches fastball or offspeed

SELECT
	100.0 * sum(case when pitch_name in ('4-Seam Fastball', 'Cutter', 'Split-Finger') then 1 else 0 end) / count(*) FastballPercent,
	100.0 * sum(case when pitch_name NOT in ('4-Seam Fastball', 'Cutter', 'Split-Finger') then 1 else 0 end) / count(*) OffspeedPercent
FROM RangersPitch.dbo.LastPitchRangers

--Top 5 most common last pitch for a relief pitcher vs a starting pitcher

SELECT *
FROM (
	SELECT 
		a.POS,
		a.pitch_name,
		a.timesthrown,
		RANK() OVER(Partition by a.POS Order by a.timesthrown desc) PitchRank
	FROM (
		SELECT RPS.POS, LPR.pitch_name, count(*) timesthrown
		FROM RangersPitch.dbo.LastPitchRangers LPR
		JOIN RangersPitch.Dbo.RangersPitchingstats RPS ON RPS.pitcher_id = LPR.pitcher
		group by RPS.POS, LPR.pitch_name
	) a
)b
WHERE b.PitchRank < 6

-- HOMERUN ANALYSIS

SELECT 
	pitch_name, 
	count(*) HRs
FROM RangersPitch.dbo.LastPitchRangers
where events = 'home_run'
group by pitch_name
order by count(*) desc


-- Homeruns given up by zone (pitch location) and pitch type

SELECT ZONE, 
	pitch_name, 
	count(*) HRs
FROM RangersPitch.dbo.LastPitchRangers
where events = 'home_run'
group by ZONE, pitch_name
order by count(*) desc

-- Homeruns for each count type with type of pitcher

SELECT 
	RPS.POS, 
	LPR.balls, 
	LPR.strikes, 
	count(*) HRs
FROM RangersPitch.dbo.LastPitchRangers LPR
JOIN RangersPitch.Dbo.RangersPitchingstats RPS ON RPS.pitcher_id = LPR.pitcher
where events = 'home_run'
group by RPS.POS, LPR.balls, LPR.strikes
order by count(*) desc

-- Each Pitchers most common count to give up a Homerun
-- add balls thrown

with hrcountpitchers as (
SELECT RPS.Name, LPR.balls, LPR.strikes, count(*) HRs
FROM RangersPitch.dbo.LastPitchRangers LPR
JOIN RangersPitch.Dbo.RangersPitchingstats RPS ON RPS.pitcher_id = LPR.pitcher
where events = 'home_run' and IP >= 30
group by RPS.Name, LPR.balls,LPR.strikes
),
hrcountranks as (
	Select 
		hcp.Name,
		hcp.balls,
		hcp.strikes,
		hcp.HRs,
	rank() OVER (Partition by Name order by HRs desc) hrrank
	FROM hrcountpitchers hcp
)
SELECT 
	ht.Name,
	ht.balls,
	ht.strikes,
	ht.HRs
FROM hrcountranks ht
where hrrank = 1

--MARTIN PEREZ STATS

-- AVG release speed, spin rate, strikeouts, most popular zone

SELECT 
	AVG(release_speed) AvgReleaseSpeed,
	AVG(release_spin_rate) AvgSpinRate,
	Sum(case when events = 'strikeout' then 1 else 0 end) strikeouts,
	max(zones.zone) as Zone
FROM RangersPitch.dbo.LastPitchRangers LPR
join(

	SELECT 
		pitcher, 
		zone, 
		count(*) zonenum
	FROM RangersPitch.dbo.LastPitchRangers LPR
	Where player_name = 'Pérez, Martín'
	group by pitcher, zone

) zones on zones.pitcher = LPR.pitcher
where player_name = 'Pérez, Martín'


-- Top pitches for each infield position 

SELECT *
FROM (
	SELECT pitch_name, count(*) timeshit, 'third' position
	FROM RangersPitch.dbo.LastPitchRangers
	WHERE hit_location = 5 and player_name = 'Pérez, Martín'
	group by pitch_name
	UNION
	SELECT pitch_name, count(*) timeshit, 'short' position
	FROM RangersPitch.dbo.LastPitchRangers
	WHERE hit_location = 6 and player_name = 'Pérez, Martín'
	group by pitch_name
	UNION
	SELECT pitch_name, count(*) timeshit, 'second' position
	FROM RangersPitch.dbo.LastPitchRangers
	WHERE hit_location = 4 and player_name = 'Pérez, Martín'
	group by pitch_name
	UNION
	SELECT pitch_name, count(*) timeshit, 'first' position
	FROM RangersPitch.dbo.LastPitchRangers
	WHERE hit_location = 3 and player_name = 'Pérez, Martín'
	group by pitch_name
) a
WHERE timeshit > 4
order by timeshit DESC


-- Balls/strikes and frequency when someone is on base

SELECT 
	balls, 
	strikes, 
	count(*) frequency
FROM RangersPitch.dbo.LastPitchRangers
WHERE (on_3b is NOT NULL or on_2b is NOT NULL or on_1b is NOT NULL)
and player_name = 'Pérez, Martín'
group by balls, strikes 


-- Pitch type and their average launch speed

SELECT  
	pitch_name, 
	avg(launch_speed * 1.00) as 'launch_speed'
FROM RangersPitch.dbo.LastPitchRangers
where player_name = 'Pérez, Martín' 
group by pitch_name
order by avg(launch_speed) desc









