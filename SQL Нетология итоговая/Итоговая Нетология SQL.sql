--В каких городах больше одного аэропорта?
select city, count(city)
from airports a
group by city
having count(city) > 1


--В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
select a.airport_code, a2.range
from airports a
join flights f on a.airport_code = f.departure_airport
join aircrafts a2 on f.aircraft_code = a2.aircraft_code
where a2.range = (
select max("range")
from aircrafts
)
group by a.airport_code, a2.range


--Вывести 10 рейсов с максимальным временем задержки вылета
select flight_id, scheduled_departure, actual_departure, (actual_departure - scheduled_departure) as time
from flights where actual_departure is not null
order by time desc
limit 10;


--Были ли брони, по которым не были получены посадочные талоны?
select count(bookings.book_ref)
from bookings
full outer join tickets on bookings.book_ref = tickets.book_ref
full outer join boarding_passes on boarding_passes.ticket_no = tickets.ticket_no
where boarding_passes.boarding_no is null;

--Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное количество вывезенных пассажиров из аэропорта за день. Т.е. в этом столбце должна отражаться сумма - 
--сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за сегодняшний день
select 
f.departure_airport, 
f.flight_id, 
all_s - oc_s as free_seats, 
round(100 - (oc_s::numeric / all_s::numeric)*100, 2) as free_seats_percentage,
f.actual_departure,
sum (oc_s) over (partition by f.departure_airport, date_trunc('day',f.actual_departure) order by f.actual_departure)
from flights f
join (
select bp.flight_id, count(bp.boarding_no) as oc_s
from ticket_flights tf 
join boarding_passes bp on bp.ticket_no = tf.ticket_no and bp.flight_id = tf.flight_id
group by bp.flight_id
) a1 on a1.flight_id = f.flight_id 		
join (
select s.aircraft_code, count(s.seat_no) as all_s
from seats s
group by s.aircraft_code
) a2 on a2.aircraft_code = f.aircraft_code

--Найдите процентное соотношение перелетов по типам самолетов от общего количества.
select
distinct f.aircraft_code,
t2.types,
count(flight_id) over() as overall,
round(t2.types::numeric*100/cast(count(flight_id) over() as numeric), 2) as percentage
from
flights f
join (
select
aircraft_code,
count (flight_id) as types
from flights
group by aircraft_code
) t2 on f.aircraft_code = t2.aircraft_code

--Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
with econom as
	(select ticket_flights.flight_id, max(amount)
	from ticket_flights
	where fare_conditions = 'Economy'
	group by ticket_flights.flight_id),
business as
	(select flight_id, min(amount) as min
	from ticket_flights
	where fare_conditions = 'Business' group by flight_id)
select e.flight_id, min, max, a1.city, a2.city
from econom e
join business b on e.flight_id = b.flight_id
left join flights f on e.flight_id = f.flight_id and b.flight_id = f.flight_id
left join airports a1 on a1.airport_code = f.arrival_airport
left join airports a2 on a2.airport_code = f.departure_airport
where max > min;

--Между какими городами нет прямых рейсов?
create view route as 
	select distinct a.city as departure_city , b.city as arrival_city, a.city||'-'||b.city as route 
	from airports as a, (select city from airports) as b
	where a.city != b.city
	order by route
	
create view direct_flight as 
	select distinct a.city as departure_city, aa.city as arrival_city, a.city||'-'|| aa.city as route  
	from flights as f
	inner join airports as a on f.departure_airport=a.airport_code
	inner join airports as aa on f.arrival_airport=aa.airport_code
	order by route
	
select r.* 
from route as r
except 
select df.* 
from direct_flight as df

--Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы
select r.departure_airport, r.arrival_airport, r.aircraft_code, ar."range",
acos(sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude - a2.longitude))*6371 as distance_between_airports
from routes r
join airports a on a.airport_code = r.departure_airport
join airports a2 on a2.airport_code = r.arrival_airport
join aircrafts ar on ar.aircraft_code = r.aircraft_code
group by r.departure_airport, r.arrival_airport, r.aircraft_code, ar."range", distance_between_airports







