--Official Report PDF
SET NOCOUNT ON

DECLARE @StartDateInput DATE = '10/01/2018'
DECLARE @EndDateInput DATE = '10/10/2018'
DECLARE @ValidationStartDate DATETIME
DECLARE @ValidationEndDate DATETIME

IF (
		@StartDateInput IS NOT NULL
		AND @EndDateInput IS NOT NULL
		)
BEGIN
	SET @ValidationStartDate = Cast(@StartDateInput AS DATETIME)
	SET @ValidationEndDate = cast(@EndDateInput AS DATETIME)
END

DECLARE @commercialorderlinestatus NVARCHAR(50) = 'Completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @ValidationStartDate)
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @ValidationEndDate)
DECLARE @ReportInput1 NVARCHAR(max) = 'State'
DECLARE @ReportInput2 NVARCHAR(max) = 'MN'
DECLARE @FieldRep NVARCHAR(max)
DECLARE @StateRep NVARCHAR(max)
DECLARE @ReportingState NVARCHAR(max)
DECLARE @ProducerGroup NVARCHAR(max)

--select @startTime, @endTime, @startTimeInUtc, @endTimeInUtc
SELECT col.id commercialorderlineid,
	col.CommercialOrderLineStatus,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
WHERE col.commercialorderlinestatus = @commercialorderlinestatus
GROUP BY col.id,
	col.CommercialOrderLineStatus
HAVING max(rr.ResultValidationDate) >= @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

SELECT DISTINCT s.id
INTO #eligiblesamples
FROM #eligibleColIds TEMP
JOIN CommercialOrderLine col ON col.id = TEMP.commercialorderlineid
JOIN sample s ON s.id = col.SampleId
WHERE col.CommercialItem IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVPG', 'MVPQVPB', 'MVPQVP8')

IF (@ReportInput1 = 'State')
BEGIN
	SET @ReportingState = @ReportInput2
	SET @FieldRep = NULL
	SET @StateRep = NULL
	SET @ProducerGroup = NULL
END
ELSE IF (@ReportInput1 = 'Field Rep')
BEGIN
	SET @FieldRep = @ReportInput2
	SET @StateRep = NULL
	SET @ReportingState = NULL
	SET @ProducerGroup = NULL
END
ELSE IF (@ReportInput1 = 'State Rep')
BEGIN
	SET @FieldRep = NULL
	SET @StateRep = @ReportInput2
	SET @ReportingState = NULL
	SET @ProducerGroup = NULL
END
ELSE IF (@ReportInput1 = 'Producer Group')
BEGIN
	SET @ProducerGroup = @ReportInput2
	SET @FieldRep = NULL
	SET @ReportingState = NULL
	SET @FieldRep = NULL
	SET @StateRep = NULL
END

SELECT --DATEADD(SS,-@SecDifference,temp.COLCompletionTime) COLCompletionTime -- convert utc to local time, this logic needs to be applied for all date columns
	P.producercode,
	P.Region,
	p.ProducerName,
	P.StateRep,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	P.PermitNumber,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	P.FieldRep,
	S.TemperatureAtSampling [Sample Temp],
	S.TemperatureAtRegistration [Parcel Temp],
	S.BillingWeek,
	col.CommercialOrderLineStatus,
	CF.InternalName [Client Name],
	cast(NULL AS NVARCHAR(50)) [Lab Tech],
	CASE 
		WHEN RR.AggregatedValue = 'NOT FOUND'
			THEN 'NF'
		WHEN RR.AggregatedValue = 'Positive'
			THEN 'AL'
		ELSE RR.AggregatedValue
		END AS AggregatedValue,
	CASE 
		-- Check until exclude 'MVPQVPAb, MVQVP41 = Plate Loop Count for Goats'
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A', 'MVPQVP8', 'MVQVP52B', 'MVQVP41')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial,
	P.BTUNumber,
	COL.CommercialItem,
	RR.ResultValidationDate
INTO #temp
FROM #eligiblesamples TEMP
JOIN sample s ON s.id = TEMP.Id
JOIN CommercialOrderLine COL ON col.SampleId = s.id
JOIN Reportableresult RR ON rr.commercialorderlineid = col.id
JOIN CommercialOrder co ON co.id = col.CommercialOrderId
JOIN CustomerFramework cf ON cf.id = co.CustomerFrameworkId
JOIN Producer p ON p.id = s.ProducerId
LEFT JOIN ProducerList pl ON pl.ProducerId = p.id
LEFT JOIN ProducerGroup pg ON pg.id = pl.ProducerGroupId
LEFT JOIN elimsmilkexternalconcerns.dbo.commercialitem CI ON COL.CommercialItem = CI.CommercialItemCode
LEFT JOIN elimsmilkexternalconcerns.dbo.TestParameter TP ON RR.CommercialParameterCode = TP.testparametercode
WHERE col.commercialorderlinestatus = @commercialorderlinestatus
	AND p.producercode IS NOT NULL
	AND s.tank IS NOT NULL
	AND s.SamplingTime IS NOT NULL
	AND (
		@ReportingState IS NULL
		OR p.Region = @ReportingState
		)
	AND (
		@StateRep IS NULL
		OR p.staterep = @StateRep
		)
	AND (
		@FieldRep IS NULL
		OR p.fieldrep = @FieldRep
		)
	AND (
		@ProducerGroup IS NULL
		OR pg.ProducerGroupName = @ProducerGroup
		)
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select * from #temp
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT *
INTO #TempFinal1
FROM (
	SELECT *
	FROM #temp
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN ([Bacteria Count], [Delvo Inhibitor], [Somatic cells], [Freezing point], [Analysis Temperature])) piv

--select * from #TempFinal1
--where ProducerCode = '220158'
--------------------------------------------------------------------------------------------------------------------------------------------------------
--Get averages for the following state, if the sample date & producer code is the same:
SELECT ProducerCode,
	Tank = STUFF((
			SELECT DISTINCT ',' + T1.Tank AS [text()]
			FROM #TempFinal1 T1
			WHERE T1.ProducerCode = t2.ProducerCode
				AND T1.SamplingTime = T2.SamplingTime
			FOR XML PATH('')
			), 1, 1, ''),
	Seq = STUFF((
			SELECT DISTINCT ',' + T1.seq AS [text()]
			FROM #TempFinal1 T1
			WHERE T1.ProducerCode = t2.ProducerCode
				AND T1.SamplingTime = T2.SamplingTime
			FOR XML PATH('')
			), 1, 1, ''),
	max(ProducerName) ProducerName,
	max(PermitNumber) PermitNumber,
	SamplingTime,
	cast(round(avg(cast([Bacteria Count] AS FLOAT)), 0) AS NVARCHAR(20)) [Bacteria Count],
	cast(round(avg(cast([Somatic Cells] AS FLOAT)), 0) AS NVARCHAR(20)) [Somatic Cells],
	cast(round(avg(cast([Freezing Point] AS FLOAT)), 0) AS NVARCHAR(20)) [Freezing Point],
	max([Delvo Inhibitor]) [Delvo Inhibitor],
	max([Region]) [Region],
	max(FieldRep) FieldRep,
	max(StateRep) StateRep,
	max([Sample Temp]) [Sample Temp],
	max([Parcel Temp]) [Parcel Temp],
	max([Client Name]) [Client Name],
	max(Barcode) Barcode,
	max([Lab Tech]) [Lab Tech],
	max([Analysis Temperature]) [Analysis Temperature],
	max(BillingWeek) BillingWeek,
	max(CommercialOrderLineStatus) CommercialOrderLineStatus,
	max(BtuNumber) BtuNumber,
	max(Isofficial) Isofficial,
	max(ResultValidationDate) ResultValidationDate
INTO #TempFinal2
FROM #TempFinal1 t2
WHERE (IsOfficial = 'Y')
	AND (len(seq) > 0)
	AND [Region] IN ('MN', 'MO', 'WI')
GROUP BY ProducerCode,
	SamplingTime
ORDER BY ProducerCode,
	SamplingTime,
	Tank,
	Seq

--select * from #TempFinal2
--------------------------------------------------------------------------------------------------------------------------------
-- The rest of the states do not get averages, join the non averages states with the averages states:
SELECT max(producercode) producercode,
	max(Tank) Tank,
	Max(Seq) Seq,
	max(ProducerName) ProducerName,
	max(PermitNumber) PermitNumber,
	max(SamplingTime) SamplingTime,
	max([Bacteria Count]) [Bacteria Count],
	max([Somatic Cells]) [Somatic Cells],
	max([Freezing Point]) [Freezing Point],
	max([Delvo Inhibitor]) [Delvo Inhibitor],
	max([Region]) [Region],
	max(FieldRep) FieldRep,
	max(StateRep) StateRep,
	max([Sample Temp]) [Sample Temp],
	max([Parcel Temp]) [Parcel Temp],
	max([Client Name]) [Client Name],
	Barcode,
	max([Lab Tech]) [Lab Tech],
	max([Analysis Temperature]) [Analysis Temperature],
	max(BillingWeek) BillingWeek,
	max(CommercialOrderLineStatus) CommercialOrderLineStatus,
	max(BTUNumber) BTUNumber,
	max(Isofficial) Isofficial,
	max(ResultValidationDate) ResultValidationDate
INTO #TempFinal3
FROM #TempFinal1
WHERE (IsOfficial = 'Y')
	AND (len(seq) > 0)
	AND [Region] NOT IN ('MN', 'MO', 'WI')
GROUP BY BarCode
ORDER BY ProducerCode,
	Tank,
	Seq,
	SamplingTime

--select * from #TempFinal3
----------------------------------------------------------------------------------------------------------------
SELECT *
INTO #TempFinal4
FROM #TempFinal2

UNION ALL

SELECT *
FROM #TempFinal3

--SELECT * 
--FROM #TempFinal4
-------------------------------------------------------------------------------------------------------------------------
UPDATE DB
SET DB.[Lab Tech] = rs.OperatorCode
FROM ReportableResult rr
JOIN CommercialOrderLine col ON col.id = rr.CommercialOrderLineId
JOIN sample s ON s.id = col.SampleId
JOIN ResultSet rs ON rs.SequenceNumber = rr.ResultSetSequenceNo
LEFT JOIN elimsmilkexternalconcerns.dbo.TestParameter TP ON RR.CommercialParameterCode = TP.testparametercode
JOIN #TempFinal4 DB ON DB.BarCode = s.BarCode
	AND tp.TestParameterCode = 'UM0004ZH'

-- Will use as a flag for any values that are missing or to get the data without averages.
DECLARE @MissingOrRawValues NVARCHAR(max) = 'All'

SET NOCOUNT OFF

IF (@MissingOrRawValues = 'ALL')
BEGIN
	SELECT *
	FROM #TempFinal4
	WHERE (
			BillingWeek IN ('N/A', 'n/a', 'NA', 'na')
			OR Tank IS NULL
			OR Tank = ''
			OR Barcode IS NULL
			OR Barcode = ''
			OR SamplingTime IS NULL
			OR SamplingTime = ''
			OR [Somatic Cells] IS NULL
			OR [Somatic Cells] = ''
			OR [Freezing Point] IS NULL
			OR [Freezing Point] = ''
			OR [Delvo Inhibitor] IS NULL
			OR [Delvo Inhibitor] = ''
			OR [Bacteria Count] IS NULL
			OR [Bacteria Count] = ''
			OR ([Sample Temp] IS NULL)
			OR ([Parcel Temp] IS NULL)
			OR ([Analysis Temperature] IS NULL)
			OR [Lab Tech] IS NULL
			OR [Lab Tech] = ''
			)
	ORDER BY [Client Name],
		ProducerCode,
		SamplingTime,
		tank
END
		-- Get the data without averages for Bruce excel project.
ELSE IF (@MissingOrRawValues = 'Raw')
BEGIN
	SELECT max(ProducerCode) ProducerCode,
		max(Tank) Tank,
		max(Seq) Seq,
		max(ProducerName) ProducerName,
		max(PermitNumber) PermitNumber,
		max(SamplingTime) SamplingTime,
		max([Bacteria Count]) [Bacteria Count],
		max([Somatic Cells]) [Somatic Cells],
		max([Freezing Point]) [Freezing Point],
		max([Delvo Inhibitor]) [Delvo Inhibitor],
		max([Region]) [Region],
		max(FieldRep) FieldRep,
		max(StateRep) StateRep,
		max([Sample Temp]) [Sample Temp],
		max([Parcel Temp]) [Parcel Temp],
		max([Client Name]) [Client Name],
		Barcode,
		max([Lab Tech]) [Lab Tech],
		max([Analysis Temperature]) [Analysis Temperature],
		max(BillingWeek) BillingWeek,
		max(CommercialOrderLineStatus) CommercialOrderLineStatus,
		max(BtuNumber) BtuNumber,
		max(Isofficial) Isofficial,
		max(ResultValidationDate) ResultValidationDate
	INTO #TempRawNoAvg
	FROM #TempFinal1
	WHERE (IsOfficial = 'Y')
		AND (len(seq) > 0)
	--AND [Region] IN ('MN', 'MO', 'WI')
	GROUP BY BarCode
	ORDER BY ProducerCode,
		SamplingTime,
		Tank,
		Seq

	UPDATE DB
	SET DB.[Lab Tech] = rs.OperatorCode
	FROM ReportableResult rr
	JOIN CommercialOrderLine col ON col.id = rr.CommercialOrderLineId
	JOIN sample s ON s.id = col.SampleId
	JOIN ResultSet rs ON rs.SequenceNumber = rr.ResultSetSequenceNo
	LEFT JOIN elimsmilkexternalconcerns.dbo.TestParameter TP ON RR.CommercialParameterCode = TP.testparametercode
	JOIN #TempRawNoAvg DB ON DB.BarCode = s.BarCode
		AND tp.TestParameterCode = 'UM0004ZH'

	SELECT *
	FROM #TempRawNoAvg
	ORDER BY [Client Name],
		ProducerCode,
		SamplingTime,
		tank

	DROP TABLE #TempRawNoAvg
END
ELSE
BEGIN
	SELECT *
	FROM #TempFinal4
	WHERE (
			BillingWeek NOT IN ('N/A', 'n/a', 'NA', 'na')
			OR BillingWeek IS NULL
			OR BillingWeek = ''
			)
		AND (
			Tank IS NOT NULL
			OR Tank != ''
			)
		AND (
			Barcode IS NOT NULL
			OR Barcode != ''
			)
		AND (
			SamplingTime IS NOT NULL
			OR SamplingTime != ''
			)
		AND (
			[Somatic Cells] IS NOT NULL
			OR [Somatic Cells] != ''
			)
		AND (
			[Freezing Point] IS NOT NULL
			OR [Freezing Point] != ''
			)
		AND (
			[Delvo Inhibitor] IS NOT NULL
			OR [Delvo Inhibitor] != ''
			)
		AND (
			[Bacteria Count] IS NOT NULL
			OR [Bacteria Count] != ''
			)
		AND ([Sample Temp] IS NOT NULL)
		AND ([Parcel Temp] IS NOT NULL)
		AND ([Analysis Temperature] IS NOT NULL)
		AND (
			[Lab Tech] IS NOT NULL
			OR [Lab Tech] != ''
			)
	ORDER BY [Client Name],
		ProducerCode,
		SamplingTime,
		tank
END

DROP TABLE #eligibleColIds

DROP TABLE #temp

DROP TABLE #TempFinal1

DROP TABLE #TempFinal2

DROP TABLE #TempFinal3

DROP TABLE #TempFinal4

DROP TABLE #eligiblesamples
