-- Special (RedTag Report)
-- All data.
DECLARE @ReportDaysInput INT = 48
DECLARE @ReportDays INT
DECLARE @CommerCialOrderCodeInput NVARCHAR(50) = 'CO18-08-001380'
DECLARE @CommerCialOrderCode NVARCHAR(50)
DECLARE @BarcodeInput NVARCHAR(max) --= '28000301932152,28000000213205,'
DECLARE @Barcode NVARCHAR(max)
DECLARE @TempBarcodeInput TABLE (Barcode NVARCHAR(50) NULL)
DECLARE @BarcodeCount INT = 0

-- search the last x amount of days.
IF (@ReportDaysInput != '')
BEGIN
	SET @ReportDays = @ReportDaysInput
END
ELSE IF (@ReportDaysInput IS NULL)
BEGIN
	SET @ReportDays = 30
END

-- Pass Commercial Order value .
IF (@CommerCialOrderCodeInput IS NOT NULL)
BEGIN
	SET @CommerCialOrderCode = @CommerCialOrderCodeInput
END

-- Barcode string Input, must use ',' as a delimiter.
IF (@BarcodeInput IS NOT NULL)
BEGIN
	SET @Barcode = @BarcodeInput

	WHILE CHARINDEX(',', @Barcode) <> 0 -- Split barcodes based on the delimiter.
	BEGIN
		INSERT INTO @TempBarcodeInput
		VALUES (
			(
				SELECT LEFT(@Barcode, CHARINDEX(',', @Barcode) - 1)
				)
			)

		SET @Barcode = (
				SELECT RIGHT(@Barcode, LEN(@Barcode) - CHARINDEX(',', @Barcode))
				)
	END

	SET @BarcodeCount = (
			SELECT count(1)
			FROM @TempBarcodeInput
			)
END

--select * from  @TempBarcodeInput 
-- Get Row count from "@TempBarcodeImput" Table 
DECLARE @commercialtest NVARCHAR(50)
DECLARE @commercialorderlinestatus NVARCHAR(50) = 'completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @endTime DATETIME = current_timestamp
DECLARE @startTime DATETIME = dateadd(day, - @ReportDays, cast(cast(@endTime AS DATE) AS DATETIME))
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, cast(cast(@startTime AS DATE) AS DATETIME))
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @endTime)

SELECT col.id commercialorderlineid,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
GROUP BY col.id
HAVING max(rr.ResultValidationDate) > @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

SELECT P.producercode,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	CF.InternalName [Client Name],
	S.ChrNumber,
	S.CkrNumber,
	CO.CommercialOrderCode,
	CASE 
		WHEN RR.AggregatedValue = 'NOT FOUND'
			THEN 'NF'
		WHEN RR.AggregatedValue = 'Positive'
			THEN 'AL'
		ELSE RR.AggregatedValue
		END AS AggregatedValue,
	CASE 
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVP9', 'MVPQVPAb', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial
INTO #Temp1
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
LEFT JOIN @TempBarcodeInput tb ON S.BarCode = TB.Barcode
WHERE col.commercialorderlinestatus = @commercialorderlinestatus
	AND CO.CommercialOrderCode = @CommerCialOrderCode
	-- Allow to pass an optional barcodes value, barcode value is not require. If barcode value is null then use CommercialOrderCode only.
	AND (
		@BarcodeCount = 0
		OR TB.Barcode IS NOT NULL
		)
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select *
--from #Temp1
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT *
INTO #Temp2
FROM (
	SELECT *
	FROM #Temp1
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN (Fat, [Freezing point], [Lactose], [Milk Urea Nitrogen (MUN)], [Other Solids], [Solids not fat (SNF)], [Somatic cells], [True Protein], [Bacteria Count], [Bacteria Count(PI)], [Coliforms], [Delvo Inhibitor], [Pregnancy], [Thermoduric Plate Count], Alkylphenolethoxylates, [Gram negative Bacteria], [Staphylococcus aureus], [Staphylococcus species], [Streptococci agalactiae], [Streptococcus species], [Prototheca species], [Mycoplasma species])) piv

SELECT *
INTO #Temp3
FROM #Temp2

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get all of the fields on one line group by the sample barcode.
SELECT Barcode,
	max(ProducerCode) ProducerCode,
	max(Tank) Tank,
	max(Seq) Seq,
	max(SamplingTime) SamplingTime,
	max([Client Name]) [Client Name],
	max(ChrNumber) ChrNumber,
	max(CKrNumber) CKrNumber,
	max(CommercialOrderCode) CommercialOrderCode,
	max(IsOfficial) IsOfficial,
	max(Fat) Fat,
	max([Freezing Point]) [Freezing Point],
	max(Lactose) Lactose,
	max([Milk Urea Nitrogen (MUN)]) [Milk Urea Nitrogen (MUN)],
	max([Other Solids]) [Other Solids],
	max([Solids not fat (SNF)]) [Solids not fat (SNF)],
	max([Somatic cells]) [Somatic cells],
	max([True Protein]) [True Protein],
	max([Bacteria Count]) [Bacteria Count],
	max([Bacteria Count(PI)]) [Bacteria Count(PI)],
	max(Coliforms) Coliforms,
	max([Delvo Inhibitor]) [Delvo Inhibitor],
	max(Pregnancy) Pregnancy,
	max([Thermoduric Plate Count]) [Thermoduric Plate Count],
	max(Alkylphenolethoxylates) Alkylphenolethoxylates,
	max([Gram negative Bacteria]) [Gram negative Bacteria],
	max([Staphylococcus aureus]) [Staphylococcus aureus],
	max([Staphylococcus species]) [Staphylococcus species],
	max([Streptococci agalactiae]) [Streptococci agalactiae],
	max([Streptococcus species]) [Streptococcus species],
	max([Prototheca species]) [Prototheca species],
	max([Mycoplasma species]) [Mycoplasma species]
INTO #Temp4
FROM #Temp3
GROUP BY Barcode

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT Barcode,
	ChrNumber,
	ProducerCode,
	Tank,
	Seq,
	SamplingTime,
	[Client Name],
	Fat,
	[Freezing Point],
	Lactose,
	[Milk Urea Nitrogen (MUN)],
	[Other Solids],
	[Solids not fat (SNF)],
	[Somatic cells],
	[True Protein],
	[Bacteria Count],
	[Bacteria Count(PI)],
	Coliforms,
	[Delvo Inhibitor],
	Pregnancy,
	[Thermoduric Plate Count],
	Alkylphenolethoxylates,
	[Gram negative Bacteria],
	[Staphylococcus aureus],
	[Staphylococcus species],
	[Streptococci agalactiae],
	[Streptococcus species],
	[Prototheca species],
	[Mycoplasma species]
FROM #Temp4
ORDER BY ProducerCode,
	Tank,
	SamplingTime

DROP TABLE #eligibleColIds

DROP TABLE #Temp1

DROP TABLE #Temp2

DROP TABLE #Temp3

DROP TABLE #Temp4

----------------------------------------------------------------------------------------------------------------------------------------------
/***Create 3 datasets for Componetns, Bacteria, Cultures ***/
----------------------------------------------------------------------------------------------------------------------------------------------
--Components
-- Special (RedTag Report)
DECLARE @ReportDaysInput INT = 48
DECLARE @ReportDays INT
DECLARE @CommerCialOrderCodeInput NVARCHAR(50) = 'CO18-08-001380'
DECLARE @CommerCialOrderCode NVARCHAR(50)
DECLARE @BarcodeInput NVARCHAR(max) --= '28000301932152,28000000213205,'
DECLARE @Barcode NVARCHAR(max)
DECLARE @TempBarcodeInput TABLE (Barcode NVARCHAR(50) NULL)
DECLARE @BarcodeCount INT = 0

-- search the last x amount of days.
IF (@ReportDaysInput != '')
BEGIN
	SET @ReportDays = @ReportDaysInput
END
ELSE IF (@ReportDaysInput IS NULL)
BEGIN
	SET @ReportDays = 30
END

-- Pass Commercial Order value .
IF (@CommerCialOrderCodeInput IS NOT NULL)
BEGIN
	SET @CommerCialOrderCode = @CommerCialOrderCodeInput
END

-- Barcode string Input, must use ',' as a delimiter.
IF (@BarcodeInput IS NOT NULL)
BEGIN
	SET @Barcode = @BarcodeInput

	WHILE CHARINDEX(',', @Barcode) <> 0 -- Split barcodes based on the delimiter.
	BEGIN
		INSERT INTO @TempBarcodeInput
		VALUES (
			(
				SELECT LEFT(@Barcode, CHARINDEX(',', @Barcode) - 1)
				)
			)

		SET @Barcode = (
				SELECT RIGHT(@Barcode, LEN(@Barcode) - CHARINDEX(',', @Barcode))
				)
	END

	SET @BarcodeCount = (
			SELECT count(1)
			FROM @TempBarcodeInput
			)
END

--select * from  @TempBarcodeInput 
-- Get Row count from "@TempBarcodeImput" Table 
DECLARE @commercialtest NVARCHAR(50)
DECLARE @commercialorderlinestatus NVARCHAR(50) = 'completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @endTime DATETIME = current_timestamp
DECLARE @startTime DATETIME = dateadd(day, - @ReportDays, cast(cast(@endTime AS DATE) AS DATETIME))
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, cast(cast(@startTime AS DATE) AS DATETIME))
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @endTime)

SELECT col.id commercialorderlineid,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
GROUP BY col.id
HAVING max(rr.ResultValidationDate) > @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

SELECT P.producercode,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	CF.InternalName [Client Name],
	S.ChrNumber,
	S.CkrNumber,
	CO.CommercialOrderCode,
	CASE 
		WHEN RR.AggregatedValue = 'NOT FOUND'
			THEN 'NF'
		WHEN RR.AggregatedValue = 'Positive'
			THEN 'AL'
		ELSE RR.AggregatedValue
		END AS AggregatedValue,
	CASE 
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVP9', 'MVPQVPAb', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial
INTO #Temp1
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
LEFT JOIN @TempBarcodeInput tb ON S.BarCode = TB.Barcode
WHERE col.commercialorderlinestatus = @commercialorderlinestatus
	AND CO.CommercialOrderCode = @CommerCialOrderCode
	-- Allow to pass an optional barcodes value, barcode value is not require. If barcode value is null then use CommercialOrderCode only.
	AND (
		@BarcodeCount = 0
		OR TB.Barcode IS NOT NULL
		)
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select *
--from #Temp1
SELECT *
INTO #Temp2
FROM (
	SELECT *
	FROM #Temp1
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN (Fat, [Freezing point], [Lactose], [Milk Urea Nitrogen (MUN)], [Other Solids], [Solids not fat (SNF)], [Somatic cells], [True Protein], [Bacteria Count], [Bacteria Count(PI)], [Coliforms], [Delvo Inhibitor], [Pregnancy], [Thermoduric Plate Count], Alkylphenolethoxylates, [Gram negative Bacteria], [Staphylococcus aureus], [Staphylococcus species], [Streptococci agalactiae], [Streptococcus species], [Prototheca species], [Mycoplasma species])) piv

SELECT *
INTO #Temp3
FROM #Temp2

-- Get all of the fields on one line group by the sample barcode.
SELECT Barcode,
	max(ProducerCode) ProducerCode,
	max(Tank) Tank,
	max(Seq) Seq,
	max(SamplingTime) SamplingTime,
	max([Client Name]) [Client Name],
	max(ChrNumber) ChrNumber,
	max(CKrNumber) CKrNumber,
	max(CommercialOrderCode) CommercialOrderCode,
	max(IsOfficial) IsOfficial,
	max(Fat) Fat,
	max([Freezing Point]) [Freezing Point],
	max(Lactose) Lactose,
	max([Milk Urea Nitrogen (MUN)]) [Milk Urea Nitrogen (MUN)],
	max([Other Solids]) [Other Solids],
	max([Solids not fat (SNF)]) [Solids not fat (SNF)],
	max([Somatic cells]) [Somatic cells],
	max([True Protein]) [True Protein],
	max([Bacteria Count]) [Bacteria Count],
	max([Bacteria Count(PI)]) [Bacteria Count(PI)],
	max(Coliforms) Coliforms,
	max([Delvo Inhibitor]) [Delvo Inhibitor],
	max(Pregnancy) Pregnancy,
	max([Thermoduric Plate Count]) [Thermoduric Plate Count],
	max(Alkylphenolethoxylates) Alkylphenolethoxylates,
	max([Gram negative Bacteria]) [Gram negative Bacteria],
	max([Staphylococcus aureus]) [Staphylococcus aureus],
	max([Staphylococcus species]) [Staphylococcus species],
	max([Streptococci agalactiae]) [Streptococci agalactiae],
	max([Streptococcus species]) [Streptococcus species],
	max([Prototheca species]) [Prototheca species],
	max([Mycoplasma species]) [Mycoplasma species]
INTO #Temp4
FROM #Temp3
GROUP BY Barcode

SELECT Barcode,
	CkrNumber,
	ChrNumber,
	ProducerCode,
	Tank,
	Seq,
	SamplingTime,
	[Client Name],
	Fat,
	[Freezing Point],
	Lactose,
	[Milk Urea Nitrogen (MUN)],
	[Other Solids],
	[Solids not fat (SNF)],
	[Somatic cells],
	[True Protein]
FROM #Temp4
WHERE (
		Fat IS NOT NULL
		OR Len(Fat) > 0
		)
	AND (
		[True Protein] IS NOT NULL
		OR Len([True Protein]) > 0
		)
	AND (
		Lactose IS NOT NULL
		OR Len(Lactose) > 0
		)
	AND (
		[Solids not fat (SNF)] IS NOT NULL
		OR len([Solids not fat (SNF)]) > 0
		)
	AND (
		[Somatic cells] IS NOT NULL
		OR len([Somatic cells]) > 0
		)
	AND (
		[Other Solids] IS NOT NULL
		OR len([Other Solids]) > 0
		)
	AND (
		[Milk Urea Nitrogen (MUN)] IS NOT NULL
		OR len([Milk Urea Nitrogen (MUN)]) > 0
		)
	AND (
		[Freezing Point] IS NOT NULL
		OR len([Freezing Point]) > 0
		)
ORDER BY ProducerCode,
	Tank,
	SamplingTime

DROP TABLE #eligibleColIds

DROP TABLE #Temp1

DROP TABLE #Temp2

DROP TABLE #Temp3

DROP TABLE #Temp4

-------------------------------------------------------------------------------------------------------------------------------------------------
-- Bacteria
-------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @ReportDaysInput INT = 48
DECLARE @ReportDays INT
DECLARE @CommerCialOrderCodeInput NVARCHAR(50) = 'CO18-08-001380'
DECLARE @CommerCialOrderCode NVARCHAR(50)
DECLARE @BarcodeInput NVARCHAR(max) --= '28000301932152,28000000213205,'
DECLARE @Barcode NVARCHAR(max)
DECLARE @TempBarcodeInput TABLE (Barcode NVARCHAR(50) NULL)
DECLARE @BarcodeCount INT = 0

-- search the last x amount of days.
IF (@ReportDaysInput != '')
BEGIN
	SET @ReportDays = @ReportDaysInput
END
ELSE IF (@ReportDaysInput IS NULL)
BEGIN
	SET @ReportDays = 30
END

-- Pass Commercial Order value .
IF (@CommerCialOrderCodeInput IS NOT NULL)
BEGIN
	SET @CommerCialOrderCode = @CommerCialOrderCodeInput
END

-- Barcode string Input, must use ',' as a delimiter.
IF (@BarcodeInput IS NOT NULL)
BEGIN
	SET @Barcode = @BarcodeInput

	WHILE CHARINDEX(',', @Barcode) <> 0 -- Split barcodes based on the delimiter.
	BEGIN
		INSERT INTO @TempBarcodeInput
		VALUES (
			(
				SELECT LEFT(@Barcode, CHARINDEX(',', @Barcode) - 1)
				)
			)

		SET @Barcode = (
				SELECT RIGHT(@Barcode, LEN(@Barcode) - CHARINDEX(',', @Barcode))
				)
	END

	SET @BarcodeCount = (
			SELECT count(1)
			FROM @TempBarcodeInput
			)
END

--select * from  @TempBarcodeInput 
-- Get Row count from "@TempBarcodeImput" Table 
DECLARE @commercialtest NVARCHAR(50)
DECLARE @commercialorderlinestatus NVARCHAR(50) = 'completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @endTime DATETIME = current_timestamp
DECLARE @startTime DATETIME = dateadd(day, - @ReportDays, cast(cast(@endTime AS DATE) AS DATETIME))
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, cast(cast(@startTime AS DATE) AS DATETIME))
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @endTime)

SELECT col.id commercialorderlineid,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
GROUP BY col.id
HAVING max(rr.ResultValidationDate) > @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

SELECT P.producercode,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	CF.InternalName [Client Name],
	S.ChrNumber,
	S.CkrNumber,
	CO.CommercialOrderCode,
	CASE 
		WHEN RR.AggregatedValue = 'NOT FOUND'
			THEN 'NF'
		WHEN RR.AggregatedValue = 'Positive'
			THEN 'AL'
		ELSE RR.AggregatedValue
		END AS AggregatedValue,
	CASE 
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVP9', 'MVPQVPAb', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial
INTO #Temp1
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
LEFT JOIN @TempBarcodeInput tb ON S.BarCode = TB.Barcode
WHERE col.commercialorderlinestatus = @commercialorderlinestatus
	AND CO.CommercialOrderCode = @CommerCialOrderCode
	-- Allow to pass an optional barcodes value, barcode value is not require. If barcode value is null then use CommercialOrderCode only.
	AND (
		@BarcodeCount = 0
		OR TB.Barcode IS NOT NULL
		)
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select *
--from #Temp1
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT *
INTO #Temp2
FROM (
	SELECT *
	FROM #Temp1
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN (Fat, [Freezing point], [Lactose], [Milk Urea Nitrogen (MUN)], [Other Solids], [Solids not fat (SNF)], [Somatic cells], [True Protein], [Bacteria Count], [Bacteria Count(PI)], [Coliforms], [Delvo Inhibitor], [Pregnancy], [Thermoduric Plate Count], Alkylphenolethoxylates, [Gram negative Bacteria], [Staphylococcus aureus], [Staphylococcus species], [Streptococci agalactiae], [Streptococcus species], [Prototheca species], [Mycoplasma species])) piv

SELECT *
INTO #Temp3
FROM #Temp2

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get all of the fields on one line group by the sample barcode.
SELECT Barcode,
	max(ProducerCode) ProducerCode,
	max(Tank) Tank,
	max(Seq) Seq,
	max(SamplingTime) SamplingTime,
	max([Client Name]) [Client Name],
	max(ChrNumber) ChrNumber,
	max(CKrNumber) CKrNumber,
	max(CommercialOrderCode) CommercialOrderCode,
	max(IsOfficial) IsOfficial,
	max(Fat) Fat,
	max([Freezing Point]) [Freezing Point],
	max(Lactose) Lactose,
	max([Milk Urea Nitrogen (MUN)]) [Milk Urea Nitrogen (MUN)],
	max([Other Solids]) [Other Solids],
	max([Solids not fat (SNF)]) [Solids not fat (SNF)],
	max([Somatic cells]) [Somatic cells],
	max([True Protein]) [True Protein],
	max([Bacteria Count]) [Bacteria Count],
	max([Bacteria Count(PI)]) [Bacteria Count(PI)],
	max(Coliforms) Coliforms,
	max([Delvo Inhibitor]) [Delvo Inhibitor],
	max(Pregnancy) Pregnancy,
	max([Thermoduric Plate Count]) [Thermoduric Plate Count],
	max(Alkylphenolethoxylates) Alkylphenolethoxylates,
	max([Gram negative Bacteria]) [Gram negative Bacteria],
	max([Staphylococcus aureus]) [Staphylococcus aureus],
	max([Staphylococcus species]) [Staphylococcus species],
	max([Streptococci agalactiae]) [Streptococci agalactiae],
	max([Streptococcus species]) [Streptococcus species],
	max([Prototheca species]) [Prototheca species],
	max([Mycoplasma species]) [Mycoplasma species]
INTO #Temp4
FROM #Temp3
GROUP BY Barcode

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT Barcode,
	CkrNumber,
	ChrNumber,
	ProducerCode,
	Tank,
	Seq,
	SamplingTime,
	[Client Name],
	[Bacteria Count],
	[Bacteria Count(PI)],
	Coliforms,
	[Delvo Inhibitor],
	Pregnancy,
	[Thermoduric Plate Count],
	Alkylphenolethoxylates
FROM #Temp4
WHERE (
		[Bacteria Count] IS NOT NULL
		OR Len([Bacteria Count]) > 0
		)
	OR (
		[Bacteria Count(PI)] IS NOT NULL
		OR Len([Bacteria Count(PI)]) > 0
		)
	OR (
		Coliforms IS NOT NULL
		OR Len(Coliforms) > 0
		)
	OR (
		[Delvo Inhibitor] IS NOT NULL
		OR Len([Delvo Inhibitor]) > 0
		)
	OR (
		Pregnancy IS NOT NULL
		OR Len(Pregnancy) > 0
		)
	OR (
		[Thermoduric Plate Count] IS NOT NULL
		OR Len([Thermoduric Plate Count]) > 0
		)
	OR (
		Alkylphenolethoxylates IS NOT NULL
		OR Len(Alkylphenolethoxylates) > 0
		)
ORDER BY ProducerCode,
	Tank,
	SamplingTime

DROP TABLE #eligibleColIds

DROP TABLE #Temp1

DROP TABLE #Temp2

DROP TABLE #Temp3

DROP TABLE #Temp4

-------------------------------------------------------------------------------------------------------------------------------------------
--Cultures
-------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @ReportDaysInput INT = 30
DECLARE @ReportDays INT
DECLARE @CommerCialOrderCodeInput NVARCHAR(50) = 'CO18-09-000246'
DECLARE @CommerCialOrderCode NVARCHAR(50)
DECLARE @BarcodeInput NVARCHAR(max) --= '28000301932152,28000000213205,'
DECLARE @Barcode NVARCHAR(max)
DECLARE @TempBarcodeInput TABLE (Barcode NVARCHAR(50) NULL)
DECLARE @BarcodeCount INT = 0

-- search the last x amount of days.
IF (@ReportDaysInput != '')
BEGIN
	SET @ReportDays = @ReportDaysInput
END
ELSE IF (@ReportDaysInput IS NULL)
BEGIN
	SET @ReportDays = 30
END

-- Pass Commercial Order value .
IF (@CommerCialOrderCodeInput IS NOT NULL)
BEGIN
	SET @CommerCialOrderCode = @CommerCialOrderCodeInput
END

-- Barcode string Input, must use ',' as a delimiter.
IF (@BarcodeInput IS NOT NULL)
BEGIN
	SET @Barcode = @BarcodeInput

	WHILE CHARINDEX(',', @Barcode) <> 0 -- Split barcodes based on the delimiter.
	BEGIN
		INSERT INTO @TempBarcodeInput
		VALUES (
			(
				SELECT LEFT(@Barcode, CHARINDEX(',', @Barcode) - 1)
				)
			)

		SET @Barcode = (
				SELECT RIGHT(@Barcode, LEN(@Barcode) - CHARINDEX(',', @Barcode))
				)
	END

	SET @BarcodeCount = (
			SELECT count(1)
			FROM @TempBarcodeInput
			)
END

--select * from  @TempBarcodeInput 
-- Get Row count from "@TempBarcodeImput" Table 
DECLARE @commercialtest NVARCHAR(50)
DECLARE @commercialorderlinestatus NVARCHAR(50) = 'completed'
DECLARE @TimeDifferenceToUTC FLOAT = - 5
DECLARE @endTime DATETIME = current_timestamp
DECLARE @startTime DATETIME = dateadd(day, - @ReportDays, cast(cast(@endTime AS DATE) AS DATETIME))
DECLARE @SecDifference FLOAT = - 1 * @TimeDifferenceToUTC * 3600
DECLARE @startTimeInUtc DATETIME = DATEADD(SS, @SecDifference, cast(cast(@startTime AS DATE) AS DATETIME))
DECLARE @endTimeInUtc DATETIME = DATEADD(SS, @SecDifference, @endTime)

SELECT col.id commercialorderlineid,
	max(rr.ResultValidationDate) COLCompletionTime
INTO #eligibleColIds
FROM Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
GROUP BY col.id
HAVING max(rr.ResultValidationDate) > @startTimeInUtc
	AND max(rr.ResultValidationDate) <= @endTimeInUtc

SELECT P.producercode,
	s.Tank,
	right(s.BarCode, 4) AS seq,
	s.BarCode,
	cast(dateadd(ss, - @SecDifference, s.SamplingTime) AS DATE) SamplingTime,
	TP.TestParameterName,
	CF.InternalName [Client Name],
	S.ChrNumber,
	S.CkrNumber,
	CO.CommercialOrderCode,
	CASE 
		WHEN RR.AggregatedValue = 'NOT FOUND'
			THEN 'NF'
		WHEN RR.AggregatedValue = 'Positive'
			THEN 'AL'
		ELSE RR.AggregatedValue
		END AS AggregatedValue,
	CASE 
		WHEN RR.CommercialTestCode IN ('MVPQVP1', 'MVPQVP2', 'MVPQVP6', 'MVPQVP8b', 'MVPQVP9', 'MVPQVPAb', 'MVPQVPG', 'MVPQVPB', 'MVQVP52A')
			THEN 'Y'
		ELSE 'N'
		END IsOfficial
INTO #Temp1
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
LEFT JOIN @TempBarcodeInput tb ON S.BarCode = TB.Barcode
WHERE col.commercialorderlinestatus = @commercialorderlinestatus
	AND CO.CommercialOrderCode = @CommerCialOrderCode
	-- Allow to pass an optional barcodes value, barcode value is not require. If barcode value is null then use CommercialOrderCode only.
	AND (
		@BarcodeCount = 0
		OR TB.Barcode IS NOT NULL
		)
ORDER BY P.ProducerCode,
	S.SamplingTime,
	S.BarCode,
	S.Tank,
	TestParameterName

--select *
--from #Temp1
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT *
INTO #Temp2
FROM (
	SELECT *
	FROM #Temp1
	) src
pivot(max(AggregatedValue) FOR TestParameterName IN (Fat, [Freezing point], [Lactose], [Milk Urea Nitrogen (MUN)], [Other Solids], [Solids not fat (SNF)], [Somatic cells], [True Protein], [Bacteria Count], [Bacteria Count(PI)], [Coliforms], [Delvo Inhibitor], [Pregnancy], [Thermoduric Plate Count], Alkylphenolethoxylates, [Gram negative Bacteria], [Staphylococcus aureus], [Staphylococcus species], [Streptococci agalactiae], [Streptococcus species], [Prototheca species], [Mycoplasma species], [Bulk Tank Coliforms])) piv

SELECT *
INTO #Temp3
FROM #Temp2

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get all of the fields on one line group by the sample barcode.
SELECT Barcode,
	max(ProducerCode) ProducerCode,
	max(Tank) Tank,
	max(Seq) Seq,
	max(SamplingTime) SamplingTime,
	max([Client Name]) [Client Name],
	max(ChrNumber) ChrNumber,
	max(CKrNumber) CKrNumber,
	max(CommercialOrderCode) CommercialOrderCode,
	max(IsOfficial) IsOfficial,
	max(Fat) Fat,
	max([Freezing Point]) [Freezing Point],
	max(Lactose) Lactose,
	max([Milk Urea Nitrogen (MUN)]) [Milk Urea Nitrogen (MUN)],
	max([Other Solids]) [Other Solids],
	max([Solids not fat (SNF)]) [Solids not fat (SNF)],
	max([Somatic cells]) [Somatic cells],
	max([True Protein]) [True Protein],
	max([Bacteria Count]) [Bacteria Count],
	max([Bacteria Count(PI)]) [Bacteria Count(PI)],
	max(Coliforms) Coliforms,
	max([Delvo Inhibitor]) [Delvo Inhibitor],
	max(Pregnancy) Pregnancy,
	max([Thermoduric Plate Count]) [Thermoduric Plate Count],
	max(Alkylphenolethoxylates) Alkylphenolethoxylates,
	max([Gram negative Bacteria]) [Gram negative Bacteria],
	max([Staphylococcus aureus]) [Staphylococcus aureus],
	max([Staphylococcus species]) [Staphylococcus species],
	max([Streptococci agalactiae]) [Streptococci agalactiae],
	max([Streptococcus species]) [Streptococcus species],
	max([Prototheca species]) [Prototheca species],
	max([Mycoplasma species]) [Mycoplasma species],
	max([Bulk Tank Coliforms]) [Bulk Tank Coliforms]
INTO #Temp4
FROM #Temp3
GROUP BY Barcode

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT Barcode,
	CkrNumber,
	ChrNumber,
	ProducerCode,
	Tank,
	Seq,
	SamplingTime,
	[Client Name],
	Alkylphenolethoxylates,
	[Gram negative Bacteria],
	[Staphylococcus aureus],
	[Staphylococcus species],
	[Streptococci agalactiae],
	[Streptococcus species],
	[Prototheca species],
	[Mycoplasma species],
	[Bulk Tank Coliforms]
FROM #Temp4
WHERE (
		Alkylphenolethoxylates IS NOT NULL
		OR len(Alkylphenolethoxylates) > 0
		)
	OR (
		[Gram negative Bacteria] IS NOT NULL
		OR len([Gram negative Bacteria]) > 0
		)
	OR (
		[Staphylococcus aureus] IS NOT NULL
		OR len([Staphylococcus aureus]) > 0
		)
	OR (
		[Staphylococcus species] IS NOT NULL
		OR len([Staphylococcus species]) > 0
		)
	OR (
		[Streptococci agalactiae] IS NOT NULL
		OR len([Streptococci agalactiae]) > 0
		)
	OR (
		[Streptococcus species] IS NOT NULL
		OR len([Streptococcus species]) > 0
		)
	OR (
		[Gram negative Bacteria] IS NOT NULL
		OR len([Prototheca species]) > 0
		)
	OR (
		[Mycoplasma species] IS NOT NULL
		OR len([Mycoplasma species]) > 0
		)
	OR (
		[Bulk Tank Coliforms] IS NOT NULL
		OR len([Bulk Tank Coliforms]) > 0
		)
ORDER BY ProducerCode,
	Tank,
	SamplingTime

DROP TABLE #eligibleColIds

DROP TABLE #Temp1

DROP TABLE #Temp2

DROP TABLE #Temp3

DROP TABLE #Temp4
