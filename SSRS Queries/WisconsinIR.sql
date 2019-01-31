--Wisconsin IR Report.
-- Need to report bacteria that are over 750,000 and cells that are over 1,000,000.
------------------------------------------------------------------------------------------------------------------------------------------------
--Bacteria
-------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @ReportDaysInput INT = 30
DECLARE @ReportDays INT

IF (@ReportDaysInput IS NOT NULL)
BEGIN
	SET @ReportDays = @ReportDaysInput
END
ELSE IF (@ReportDaysInput IS NULL)
BEGIN
	-- Set the last 7 days as default if
	SET @ReportDays = 7
END

DECLARE @commercialtest NVARCHAR(50)
DECLARE @commercialorderlinestatus NVARCHAR(50) = 'Completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @endTime DATETIME = current_timestamp
DECLARE @startTime DATETIME = dateadd(day, - @ReportDays, cast(cast(@endTime AS DATE) AS DATETIME))
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, cast(cast(@startTime AS DATE) AS DATETIME))
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @endTime)
DECLARE @ReportInput1 NVARCHAR(20) = 'State'
DECLARE @ReportInput2 NVARCHAR(20) = 'WI'
DECLARE @FieldRep NVARCHAR(20)
DECLARE @StateRep NVARCHAR(50)
DECLARE @ReportingState NVARCHAR(20)

--select @startTime, @endTime, @startTimeInUtc, @endTimeInUtc
SELECT col.id commercialorderlineid,
	col.CommercialOrderLineStatus,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
GROUP BY col.id,
	col.CommercialOrderLineStatus
HAVING max(rr.ResultValidationDate) > @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

IF (@ReportInput1 = 'State')
BEGIN
	SET @ReportingState = @ReportInput2
	SET @FieldRep = NULL
	SET @StateRep = NULL
END
ELSE IF (@ReportInput1 = 'Field Rep')
BEGIN
	SET @FieldRep = @ReportInput2
	SET @StateRep = NULL
	SET @ReportingState = NULL
END
ELSE IF (@ReportInput1 = 'State Rep')
BEGIN
	SET @FieldRep = NULL
	SET @StateRep = @ReportInput2
	SET @ReportingState = NULL
END

SELECT P.producercode,
	P.Region,
	p.ProducerName,
	P.StateRep,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	P.PermitNumber,
	coalesce(cast(dateadd(ss, - @SecDifference, RR.ResultMeasuredTime) AS DATE), cast(dateadd(ss, - @SecDifference, RR.ResultValidationDate) AS DATE)) Testdate,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	P.FieldRep,
	S.TemperatureAtSampling [Sample Temp],
	S.TemperatureAtRegistration [Parcel Temp],
	S.BillingWeek,
	TEMP.CommercialOrderLineStatus,
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
		-- Check until exclude 'MVPQVPAb'
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A', 'MVPQVP8', 'MVQVP52B')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial,
	P.BTUNumber
INTO #temp
FROM #eligibleColIds TEMP
JOIN Reportableresult RR ON rr.commercialorderlineid = TEMP.commercialorderlineid
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
JOIN sample s ON s.id = col.SampleId
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
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select * from #temp order by [Lab Tech]
SELECT *
INTO #TempFinal1
FROM (
	SELECT *
	FROM #temp
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN ([Bacteria Count], [Analysis Temperature] /*, [Delvo Inhibitor], [Somatic cells], [Freezing point],*/)) piv

--select * from #TempFinal1
--where ProducerCode = '220158'
SELECT max(ProducerCode) ProducerCode,
	max(Seq) Seq,
	max(Tank) Tank,
	max(ProducerName) ProducerName,
	max(PermitNumber) PermitNumber,
	max(SamplingTime) SamplingTime,
	max(Testdate) TestDate,
	max([Bacteria Count]) [Bacteria Count],
	--max([Somatic Cells]) [Somatic Cells],
	--max([Freezing Point]) [Freezing Point],
	--max([Delvo Inhibitor]) [Delvo Inhibitor],
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
	max(BtuNumber) BtuNumber
INTO #TempFinal2
FROM #TempFinal1 t2
WHERE (IsOfficial = 'Y')
	AND (len(seq) > 0)
	AND [Region] IN ('WI')
GROUP BY ProducerCode,
	BarCode
ORDER BY ProducerCode,
	SamplingTime,
	Tank,
	Seq

--select * from #TempFinal2
UPDATE DB
SET DB.[Lab Tech] = rs.OperatorCode
FROM ReportableResult rr
JOIN CommercialOrderLine col ON col.id = rr.CommercialOrderLineId
JOIN sample s ON s.id = col.SampleId
JOIN ResultSet rs ON rs.SequenceNumber = rr.ResultSetSequenceNo
LEFT JOIN elimsmilkexternalconcerns.dbo.TestParameter TP ON RR.CommercialParameterCode = TP.testparametercode
JOIN #TempFinal2 DB ON DB.BarCode = s.BarCode
	AND tp.TestParameterCode = 'UM0004ZH'

SELECT *
INTO #TempFinal3
FROM #TempFinal2
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
	--AND (
	--	[Somatic Cells] IS NOT NULL
	--	OR [Somatic Cells] != ''
	--	)
	--AND (
	--	[Freezing Point] IS NOT NULL
	--	OR [Freezing Point] != ''
	--	)
	--AND (
	--	[Delvo Inhibitor] IS NOT NULL
	--	OR [Delvo Inhibitor] != ''
	--	)
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

SELECT [Client Name],
	ProducerCode,
	Barcode,
	cast([Bacteria Count] AS INT) * 1000 [Bacteria Count],
	SamplingTime,
	TestDate,
	[Sample Temp],
	[Analysis Temperature]
FROM #TempFinal3
WHERE cast([Bacteria Count] AS INT) > 750
ORDER BY ProducerCode,
	SamplingTime,
	TestDate

DROP TABLE #eligibleColIds

DROP TABLE #temp

DROP TABLE #TempFinal1

DROP TABLE #TempFinal2

DROP TABLE #TempFinal3

----------------------------------------------------------------------------------------------------------------------------------------------------
--Somatic Cells
---------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @ReportDaysInput INT = 30
DECLARE @ReportDays INT

IF (@ReportDaysInput IS NOT NULL)
BEGIN
	SET @ReportDays = @ReportDaysInput
END
ELSE IF (@ReportDaysInput IS NULL)
BEGIN
	-- Set the last 7 days as default if
	SET @ReportDays = 7
END

DECLARE @commercialtest NVARCHAR(50)
DECLARE @commercialorderlinestatus NVARCHAR(50) = 'Completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @endTime DATETIME = current_timestamp
DECLARE @startTime DATETIME = dateadd(day, - @ReportDays, cast(cast(@endTime AS DATE) AS DATETIME))
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, cast(cast(@startTime AS DATE) AS DATETIME))
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @endTime)
DECLARE @ReportInput1 NVARCHAR(20) = 'State'
DECLARE @ReportInput2 NVARCHAR(20) = 'WI'
DECLARE @FieldRep NVARCHAR(20)
DECLARE @StateRep NVARCHAR(50)
DECLARE @ReportingState NVARCHAR(20)

--select @startTime, @endTime, @startTimeInUtc, @endTimeInUtc
SELECT col.id commercialorderlineid,
	col.CommercialOrderLineStatus,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
GROUP BY col.id,
	col.CommercialOrderLineStatus
HAVING max(rr.ResultValidationDate) > @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

IF (@ReportInput1 = 'State')
BEGIN
	SET @ReportingState = @ReportInput2
	SET @FieldRep = NULL
	SET @StateRep = NULL
END
ELSE IF (@ReportInput1 = 'Field Rep')
BEGIN
	SET @FieldRep = @ReportInput2
	SET @StateRep = NULL
	SET @ReportingState = NULL
END
ELSE IF (@ReportInput1 = 'State Rep')
BEGIN
	SET @FieldRep = NULL
	SET @StateRep = @ReportInput2
	SET @ReportingState = NULL
END

SELECT P.producercode,
	P.Region,
	p.ProducerName,
	P.StateRep,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	P.PermitNumber,
	coalesce(cast(dateadd(ss, - @SecDifference, RR.ResultMeasuredTime) AS DATE), cast(dateadd(ss, - @SecDifference, RR.ResultValidationDate) AS DATE)) Testdate,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	P.FieldRep,
	S.TemperatureAtSampling [Sample Temp],
	S.TemperatureAtRegistration [Parcel Temp],
	S.BillingWeek,
	TEMP.CommercialOrderLineStatus,
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
		-- Check until exclude 'MVPQVPAb'
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A', 'MVPQVP8', 'MVQVP52B')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial,
	P.BTUNumber
INTO #temp
FROM #eligibleColIds TEMP
JOIN Reportableresult RR ON rr.commercialorderlineid = TEMP.commercialorderlineid
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
JOIN sample s ON s.id = col.SampleId
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
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select * from #temp order by [Lab Tech]
SELECT *
INTO #TempFinal1
FROM (
	SELECT *
	FROM #temp
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN ([Somatic Cells], [Analysis Temperature] /*, [Delvo Inhibitor], [Somatic cells], [Freezing point],*/)) piv

--select * from #TempFinal1
--where ProducerCode = '220158'
SELECT max(ProducerCode) ProducerCode,
	max(Seq) Seq,
	max(Tank) Tank,
	max(ProducerName) ProducerName,
	max(PermitNumber) PermitNumber,
	max(SamplingTime) SamplingTime,
	max(Testdate) TestDate,
	--max([Bacteria Count]) [Bacteria Count],
	max([Somatic Cells]) [Somatic Cells],
	--max([Freezing Point]) [Freezing Point],
	--max([Delvo Inhibitor]) [Delvo Inhibitor],
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
	max(BtuNumber) BtuNumber
INTO #TempFinal2
FROM #TempFinal1 t2
WHERE (IsOfficial = 'Y')
	AND (len(seq) > 0)
	AND [Region] IN ('WI')
GROUP BY ProducerCode,
	BarCode
ORDER BY ProducerCode,
	SamplingTime,
	Tank,
	Seq

--select * from #TempFinal2
UPDATE DB
SET DB.[Lab Tech] = rs.OperatorCode
FROM ReportableResult rr
JOIN CommercialOrderLine col ON col.id = rr.CommercialOrderLineId
JOIN sample s ON s.id = col.SampleId
JOIN ResultSet rs ON rs.SequenceNumber = rr.ResultSetSequenceNo
LEFT JOIN elimsmilkexternalconcerns.dbo.TestParameter TP ON RR.CommercialParameterCode = TP.testparametercode
JOIN #TempFinal2 DB ON DB.BarCode = s.BarCode
	AND tp.TestParameterCode = 'UM0004ZH'

SELECT *
INTO #TempFinal3
FROM #TempFinal2
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
		OR len([Somatic Cells]) > 0
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

SELECT [Client Name],
	ProducerCode,
	Barcode,
	cast([Somatic Cells] AS INT) * 1000 [Somatic Cells],
	SamplingTime,
	TestDate,
	[Sample Temp],
	[Analysis Temperature]
FROM #TempFinal3
WHERE cast([Somatic Cells] AS INT) > 1000
ORDER BY ProducerCode,
	SamplingTime,
	TestDate

DROP TABLE #eligibleColIds

DROP TABLE #temp

DROP TABLE #TempFinal1

DROP TABLE #TempFinal2

DROP TABLE #TempFinal3
