declare @producergroup nvarchar(50) = 'ddtl Alle'
declare @samplingtime datetime
declare @commercialtest nvarchar(50)
declare @reportDays float = -90
declare @prodStateRep nvarchar(50)
declare @prodeState nvarchar(50)
declare @customercode nvarchar(50) ='ASC004588'
declare @commercialorderlinestatus nvarchar(50) ='completed'
declare @TimeDifferenceToUTC float = -5  -- US location to utc difference in hrs

declare @endTime datetime =  current_timestamp -- Get current timestamp
declare @startTime datetime = dateadd(day, @reportDays, @endTime)

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
P.producercode, P.State, p.ProducerName, P.StateRep,p.Grade, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime,
s.TemperatureAtSampling, TP.TestParameterName, RR.AggregatedValue,

case 
    when RR.AggregatedValue = 'Not Found' and RR.CommercialParameterCode = 'Z001JJPC' then '2'
	when RR.AggregatedValue = 'Positive' and RR.CommercialParameterCode = 'Z001JJPC' then '1'
    when RR.CommercialParameterCode != 'Z001JJPC' then '0'
end as IHB,

case 
    when RR.CommercialParameterCode = 'JJ00047N'
    then coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
    else coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
end SccTestDate,

case 
    when RR.CommercialParameterCode = 'UM0004ZH'
    then coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
    else coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
end SpcTestDate,

case 
    when p.Grade is null then '0'
    else p.Grade
end MilkGrade

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

select *
into #final
from
(
select * from #temp --where BarCode ='34001704719609'
)src
pivot -- Function to pivot the test results to the test parameter name
(
  max(AggregatedValue)
  for TestParameterName in ([Bacteria], [Somatic cells])
) piv

-- Nedd: State#, BTU#, escc test date, plc test date.
select ProducerCode, SamplingTime, TemperatureAtSampling, [Somatic cells], Bacteria, IHB,
'00' [ST#], '000' [Plant BTU#], '00000' [FIXED(5)], '0' [Fixed(1)], SccTestDate, SpcTestDate,
'000000' [FIXED(6)], '00000000' [FIXED(8)], MilkGrade

from #final
where (ProducerCode is not null) and (Tank is not null)
and (Barcode is not null) and (SamplingTime is not  null)
and ([Somatic cells] is not null)
--and ([Delvo Inhibitor] is not null) and (Bacteria is not null)
and (len(seq) > 0) 

drop table #final
drop table #temp
drop table #eligibleColIds 