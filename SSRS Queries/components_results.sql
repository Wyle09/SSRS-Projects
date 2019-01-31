declare @producergroup nvarchar(50) = 'ddtl Alle'
declare @samplingtime datetime
declare @commercialtest nvarchar(50)
declare @customercode nvarchar(50) ='ASC004588'
declare @commercialorderlinestatus nvarchar(50) ='completed'
declare @TimeDifferenceToUTC float = -5  -- US location to utc difference in hrs
declare @reportDays float = -20
declare @endTime datetime =  current_timestamp -- Get current timestamp
declare @startTime datetime = dateadd(day, @reportDays, @endTime) -- get the end time - 7 days. 

declare @SecDifference FLOAT= -1*@TimeDifferenceToUTC*3600 --convert the local times to utc with below logic
declare @startTimeInUtc datetime = DATEADD(SS,@SecDifference,@startTime)
declare @endTimeInUtc datetime =  DATEADD(SS,@SecDifference,@endTime)

select col.id commercialorderlineid, max(rr.ResultValidationDate) COLCompletionTime
into #eligibleColIds
from Reportableresult RR
JOIN CommercialOrderLine COL ON col.id = rr.commercialorderlineid
group by col.id
having max(rr.ResultValidationDate) > @startTimeInUtc and max(rr.ResultValidationDate) <= @endTimeInUtc


select --DATEADD(SS,-@SecDifference,temp.COLCompletionTime) COLCompletionTime -- convert utc to local time, this logic needs to be applied for all date columns
P.producercode, s.Tank, substring(s.BarCode, 11, 4) as seq, s.BarCode, P.VisitNumber, s.SamplingTime, TP.TestParameterName, RR.AggregatedValue
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
JOIN elimsmilkexternalconcerns.dbo.CommercialItemTestParameterMap CPM ON (CI.CommercialItemCode = CPM.CommercialItemId) 
join elimsmilkexternalconcerns.dbo.TestParameter TP ON (CPM.TestParameterCode = TP.TestParameterCode AND RR.CommercialParameterCode = TP.testparametercode)
where col.commercialorderlinestatus = @commercialorderlinestatus 
--and pg.producergroupname = @producergroup
--and cf.customercode = @customercode
order by P.ProducerCode, S.SamplingTime, S.BarCode, S.Tank, TP.TestParameterName

--select distinct * from #temp --where BarCode ='34001704719609'

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
        [Other Solids],[Solids not fat (SNF)],[Somatic cells],[True Protein])
    ) piv

select * from #final 
where (ProducerCode is not null) and (Tank is not null) 
and (BarCode is not null) and (SamplingTime is not null)
and (Fat is not null) and ([Freezing point] is not null)
and (Lactose is not null) and ([Milk Urea Nitrogen (MUN)] is not null)
and ([Other Solids] is not null) and ([Solids not fat (SNF)] is not null)
and ([Somatic cells] is not null) and ([True Protein] is not null)
and (len(seq) > 0)

drop table #final
drop table #temp
drop table #eligibleColIds