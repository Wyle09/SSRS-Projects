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
P.producercode, P.RouteNumber, P.State, p.ProducerName, P.StateRep,p.Grade, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime,
s.TemperatureAtSampling, TP.TestParameterName, RR.AggregatedValue,

case 
    when RR.AggregatedValue = 'Not Found' and RR.CommercialParameterCode = 'Z001JJPC' then 'NF'
	when RR.AggregatedValue = 'Positive' and RR.CommercialParameterCode = 'Z001JJPC' then 'AL'
    else 'NT'
end as IHB

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
    for TestParameterName in ([Fat],[Freezing point],[Lactose],[Milk Urea Nitrogen (MUN)],
    [Other Solids],[Solids not fat (SNF)],[Somatic cells],[True Protein], [Bacteria],
	[Pre-incubation Count (PI)], [Coliforms], [Lab Pasteurized Count])
) piv

select '27-B-00134' [Lab Number], '' [Division], ProducerCode [Member], Tank, 'T54048' [Permit],
ProducerName [Producer Name], '' [Class], cast(SamplingTime as date) [Pickup Date], 
format(cast(SamplingTime as time), 'hh\:mm') [Pickup Time], '00/00/00' [Recd Date],
TemperatureAtSampling [Temp-F], Bacteria [SPC (x1000)], Bacteria [SPC Reported (x1000)],
'BSC' [SPC Source], [Somatic cells], IHB [AB Delvo 5 Pack], '' Sedi, [Freezing point] FreezePoint,
'47-167' BTU, RouteNumber [Route], '' [Load]

  
from #final
where (ProducerCode is not null) and (Tank is not null)
and (Barcode is not null) and (SamplingTime is not  null)
and ([Somatic cells] is not null) and ([Freezing point] is not null)
--and ([Delvo Inhibitor] is not null) and (Bacteria is not null)
and (len(seq) > 0)  

drop table #final
drop table #temp
drop table #eligibleColIds


