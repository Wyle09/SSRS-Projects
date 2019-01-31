-- Using this query as the final query.

declare @producergroup nvarchar(50) = 'ddtl Alle'
declare @samplingtime datetime
declare @commercialtest nvarchar(50)
declare @reportDays float = -20
declare @prodStateRep nvarchar(50)
declare @prodeState nvarchar(50)
declare @customercode nvarchar(50) ='ASC004588'
declare @commercialorderlinestatus nvarchar(50) ='completed'
declare @TimeDifferenceToUTC float = -5  -- US location to utc difference in hrs

declare @endTime datetime =  current_timestamp -- Get current timestamp
declare @startTime datetime = dateadd(day, @reportDays, @endTime) -- get the end time - 7 days. 

declare @SecDifference FLOAT= -1*@TimeDifferenceToUTC*3600
--convert the local times to utc with below logic
declare @startTimeInUtc datetime = DATEADD(SS,@SecDifference,@startTime)
declare @endTimeInUtc datetime =  DATEADD(SS,@SecDifference,@endTime)

select  col.id commercialorderlineid, max(rr.ResultValidationDate) COLCompletionTime
into  #eligibleColIds
from Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
group by col.id
having max(rr.ResultValidationDate) > @startTimeInUtc and max(rr.ResultValidationDate) <= @endTimeInUtc


select --DATEADD(SS,-@SecDifference,temp.COLCompletionTime) COLCompletionTime -- convert utc to local time, this logic needs to be applied for all date columns
P.producercode, P.State, p.ProducerName, P.StateRep, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime,
TP.TestParameterName, 

-- Need to convert 'Not Found' string to 'NF' for the report
case 
  when RR.AggregatedValue = 'NOT FOUND' then 'NF'
  else RR.AggregatedValue
end as AggregatedValue

into #temp
from   #eligibleColIds temp
join Reportableresult RR on rr.commercialorderlineid = temp.commercialorderlineid
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
join sample s on s.id = col.SampleId
join CommercialOrder co on co.id = col.CommercialOrderId
join CustomerFramework cf on cf.id = co.CustomerFrameworkId
join Producer p on p.id = s.ProducerId
left join ProducerList pl on pl.ProducerId = p.id
left join ProducerGroup pg on pg.id = pl.ProducerGroupId
JOIN elimsmilkexternalconcerns.dbo.commercialitem CI ON COL.CommercialItem = CI.CommercialItemCode
JOIN elimsmilkexternalconcerns.dbo.CommercialItemTestParameterMap CPM ON (CI.CommercialItemCode = CPM.CommercialItemId ) 
join elimsmilkexternalconcerns.dbo.TestParameter TP ON (CPM.TestParameterCode = TP.TestParameterCode AND RR.CommercialParameterCode = TP.testparametercode)
where col.commercialorderlinestatus = @commercialorderlinestatus 
and P.State = 'IA' 
and p.producercode is not null
and s.tank is not null
and s.SamplingTime is not null
--and pg.producergroupname = @producergroup
--and cf.customercode = @customercode
order by P.ProducerCode, S.SamplingTime, S.BarCode, S.Tank, TestParameterName

--select distinct * from #temp --where BarCode ='34001704719609'

select *
into #final
from
(
select * from #temp --where BarCode ='34001704719609'
)src
pivot -- Function to pivot the test results to the test parameter name
(
  max(AggregatedValue)
  for TestParameterName in ([Bacteria],[Delvo Inhibitor], [Somatic cells], [Freezing point])
) piv

-- select * from #final

select producercode, tank, seq, ProducerName, VisitNumber, SamplingTime, Bacteria, [Somatic cells], [Freezing point], [Delvo Inhibitor]
from #final
where (ProducerCode is not null) and (Tank is not null)
and (Barcode is not null) and (SamplingTime is not  null)
and ([Somatic cells] is not null) and ([Freezing point] is not null)
--and ([Delvo Inhibitor] is not null) and (Bacteria is not null)
and (len(seq) > 0) 

drop table #final
drop table #temp
drop table #eligibleColIds 

------------------------------------------------------------------------------------------------------

declare @producergroup nvarchar(50) = 'ddtl Alle'
declare @samplingtime datetime
declare @commercialtest nvarchar(50)
declare @customercode nvarchar(50) ='ASC004588'
declare @commercialorderlinestatus nvarchar(50) ='completed'
declare @TimeDifferenceToUTC float = -5  -- US location to utc difference in hrs

declare @endTime datetime =  current_timestamp -- Get current timestamp
declare @startTime datetime = dateadd(day, -7, @endTime) -- get the end time - 7 days. 

declare @SecDifference FLOAT= -1*@TimeDifferenceToUTC*3600
--convert the local times to utc with below logic
declare @startTimeInUtc datetime = DATEADD(SS,@SecDifference,@startTime)
declare @endTimeInUtc datetime =  DATEADD(SS,@SecDifference,@endTime)

select  col.id commercialorderlineid, max(rr.ResultValidationDate) COLCompletionTime
into  #eligibleColIds
from Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
group by col.id
having max(rr.ResultValidationDate) > @startTimeInUtc and max(rr.ResultValidationDate) <= @endTimeInUtc


select --DATEADD(SS,-@SecDifference,temp.COLCompletionTime) COLCompletionTime -- convert utc to local time, this logic needs to be applied for all date columns
P.producercode, P.State, P.StateRep, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime,
TP.TestParameterName, 

-- Need to convert 'Not Found' string to 'NF' for the report
case 
  when RR.AggregatedValue = 'NOT FOUND' then 'NF'
  else RR.AggregatedValue
end as AggregatedValue

into #temp
from   #eligibleColIds temp
join Reportableresult RR on rr.commercialorderlineid = temp.commercialorderlineid
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
join sample s on s.id = col.SampleId
join CommercialOrder co on co.id = col.CommercialOrderId
join CustomerFramework cf on cf.id = co.CustomerFrameworkId
join Producer p on p.id = s.ProducerId
left join ProducerList pl on pl.ProducerId = p.id
left join ProducerGroup pg on pg.id = pl.ProducerGroupId
JOIN elimsmilkexternalconcerns.dbo.commercialitem CI ON COL.CommercialItem = CI.CommercialItemCode
JOIN elimsmilkexternalconcerns.dbo.CommercialItemTestParameterMap CPM ON (CI.CommercialItemCode = CPM.CommercialItemId ) 
join elimsmilkexternalconcerns.dbo.TestParameter TP ON (CPM.TestParameterCode = TP.TestParameterCode AND RR.CommercialParameterCode = TP.testparametercode)
where col.commercialorderlinestatus = @commercialorderlinestatus 
and P.State = 'IA' 
and p.producercode is not null
and s.tank is not null
and s.SamplingTime is not null
--and pg.producergroupname = @producergroup
--and cf.customercode = @customercode
order by P.ProducerCode, S.SamplingTime, S.BarCode, S.Tank, TestParameterName

--select distinct * from #temp --where BarCode ='34001704719609'

select *
from
(
select * from #temp --where BarCode ='34001704719609'
)src
pivot -- Function to pivot the test results to the test parameter name
(
  max(AggregatedValue)
  for TestParameterName in ([Bacteria],[Delvo Inhibitor],[Fat],[Freezing point],[Lactose],[Milk Urea Nitrogen (MUN)],
  [Other Solids],[Solids not fat (SNF)],[Somatic cells],[True Protein], [Pre-incubation Count (PI)])
) piv

drop table #temp
drop table #eligibleColIds 

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

--Get total number of tests 
declare @producergroup nvarchar(50) = 'ddtl Alle'
declare @samplingtime datetime
declare @commercialtest nvarchar(50)
declare @customercode nvarchar(50) ='ASC004588'
declare @commercialorderlinestatus nvarchar(50) ='completed'
declare @TimeDifferenceToUTC float = -5  -- US location to utc difference in hrs

declare @endTime datetime =  current_timestamp -- Get current timestamp
declare @startTime datetime = dateadd(day, -7, @endTime) -- get the end time - 7 days. 

declare @SecDifference FLOAT= -1*@TimeDifferenceToUTC*3600
--convert the local times to utc with below logic
declare @startTimeInUtc datetime = DATEADD(SS,@SecDifference,@startTime)
declare @endTimeInUtc datetime =  DATEADD(SS,@SecDifference,@endTime)

select  col.id commercialorderlineid, max(rr.ResultValidationDate) COLCompletionTime
into  #eligibleColIds
from Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
group by col.id
having max(rr.ResultValidationDate) > @startTimeInUtc and max(rr.ResultValidationDate) <= @endTimeInUtc


select --DATEADD(SS,-@SecDifference,temp.COLCompletionTime) COLCompletionTime -- convert utc to local time, this logic needs to be applied for all date columns
P.producercode, P.State, P.StateRep, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime, TP.TestParameterName, 

-- CI.commercialitemname, removed the commercialItemName because it was giving duplicate barcodes.

-- Need to convert 'Not Found' string to 'NF' for the report
case 
  when RR.AggregatedValue = 'NOT FOUND' then 'NF'
  else RR.AggregatedValue
end as AggregatedValue

into #temp1
from   #eligibleColIds temp
join Reportableresult RR on rr.commercialorderlineid = temp.commercialorderlineid
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
join sample s on s.id = col.SampleId
join CommercialOrder co on co.id = col.CommercialOrderId
join CustomerFramework cf on cf.id = co.CustomerFrameworkId
join Producer p on p.id = s.ProducerId
left join ProducerList pl on pl.ProducerId = p.id
left join ProducerGroup pg on pg.id = pl.ProducerGroupId
JOIN elimsmilkexternalconcerns.dbo.commercialitem CI ON COL.CommercialItem = CI.CommercialItemCode
JOIN elimsmilkexternalconcerns.dbo.CommercialItemTestParameterMap CPM ON (CI.CommercialItemCode = CPM.CommercialItemId ) 
join elimsmilkexternalconcerns.dbo.TestParameter TP ON (CPM.TestParameterCode = TP.TestParameterCode AND RR.CommercialParameterCode = TP.testparametercode)
where col.commercialorderlinestatus = @commercialorderlinestatus 
and P.State = 'IA' 
and p.producercode is not null
and s.tank is not null
and s.SamplingTime is not null 
--and pg.producergroupname = @producergroup
--and cf.customercode = @customercode
order by P.ProducerCode, S.SamplingTime, S.BarCode, S.Tank, TestParameterName

select *
from
(
select * from #temp1 --where BarCode ='34001704719609'
)src
pivot -- Function to pivot the test results to the test parameter name
(
  max(AggregatedValue)
  for TestParameterName in ([Bacteria],[Delvo Inhibitor],[Fat],[Freezing point],[Lactose],[Milk Urea Nitrogen (MUN)],
  [Other Solids],[Solids not fat (SNF)],[Somatic cells],[True Protein], [Pre-incubation Count (PI)])
) piv


select * 
from
  (
  select count(distinct BarCode) as numOfTests from #temp1
	where SamplingTime is not null 
	and tank is not null
  ) as total

drop table #temp1
drop table #eligibleColIds

-- Note: SSRS only allows one final query, make prior queries into temp tables.
