declare @producergroup nvarchar(50) = 'ddtl Alle'
declare @samplingtime datetime
declare @commercialtest nvarchar(50)
declare @reportDays float = -90
declare @prodStateRep nvarchar(50)
declare @prodeState nvarchar(50)
declare @customercode nvarchar(50) = 'ASC004588'
declare @commercialorderlinestatus nvarchar(50) = 'completed'
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
P.producercode, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime, s.TemperatureAtSampling, TP.TestParameterName, RR.AggregatedValue,

case 
    when RR.AggregatedValue = 'Not Found' and RR.CommercialParameterCode = 'Z001JJPC' then 'NF'
	when RR.AggregatedValue = 'Positive' and RR.CommercialParameterCode = 'Z001JJPC' then 'AL'
    else 'NT'
end as IHB,

case 
    when RR.AggregatedValue = 'Not Found' and RR.CommercialParameterCode = 'Z001JJPC' then '2'
	when RR.AggregatedValue = 'Positive' and RR.CommercialParameterCode = 'Z001JJPC' then '1'
    else '0'
end as [Anti #],

case 
    when CI.CommercialItemCode = 'MVPQVP8' then '99'
	else null
end as Official,

case
    when RR.CommercialParameterCode = 'UM0004ZH' or RR.CommercialParameterCode = '7027A006'
	then coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
	else coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
end TestDate,

case 
    when RR.CommercialParameterCode = '7027A006'
    then coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
	else coalesce(dateadd(ss, -@SecDifference, RR.ResultValidationDate), dateadd(ss, -@SecDifference, RR.ResultMeasuredTime))
end CompTestDate

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
select * from #temp
)src
pivot -- Function to pivot the test results to the test parameter name
(
     max(AggregatedValue)
    for TestParameterName in ([Fat],[Freezing point],[Lactose],[Milk Urea Nitrogen (MUN)],
    [Other Solids],[Solids not fat (SNF)],[Somatic cells],[True Protein], [Bacteria],
	[Pre-incubation Count (PI)], [Coliforms], [Lab Pasteurized Count])
) piv

select '01' [DSI Company], '141' [DSI Division], ProducerCode, '' [Load], '0' Fixed1, SamplingTime, TestDate,
Official, Fat, [True Protein], [Lactose], [Solids not fat (SNF)], '' [Total Solids], 
[Somatic cells], TemperatureAtSampling, [Bacteria], [Freezing point], '00.00' Water,
 '' Blank1, IHB, '' Sedi, '' Blank2, Tank, '' Blank3, 'DQCI' [Fixed DQCI], [Coliforms], 
[Lab Pasteurized Count], [Pre-incubation Count (PI)], '' Blank4, seq, '' [Sample ID ?],
[Milk Urea Nitrogen (MUN)], '0' Fixed2, [Anti #],'0' Fixed3, CompTestDate, '0' Fixed4   
from #final
where (ProducerCode is not null) and (Tank is not null)
and (Barcode is not null) and (SamplingTime is not  null)
and ([Somatic cells] is not null) and ([Freezing point] is not null)
--and ([Delvo Inhibitor] is not null) and (Bacteria is not null)
and (len(seq) > 0)  

drop table #eligibleColIds
drop table #temp
drop table #final