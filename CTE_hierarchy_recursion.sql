use [TerrasoftTest]
go

------------------------ script to create table -----------------------------------
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--CREATE TABLE [dbo].[Users](
--	[Id] [int] NOT NULL,
--	[Name] [nvarchar](50) NULL,
--	[BossId] [int] NULL,
-- CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED 
--(
--	[Id] ASC
--)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
--) ON [PRIMARY]

--GO
--ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [FK_User_User] FOREIGN KEY([BossId])
--REFERENCES [dbo].[Users] ([Id])
--GO
--ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [FK_User_User]
--GO


--delete helper functions (in order to recreate further)
if exists ( select * from sysobjects where id = object_id('IfProcExist')  
		and OBJECTPROPERTY(id, 'IsScalarFunction') = 1 )
		drop function [dbo].IfProcExist
go 

if exists ( select * from sysobjects where id = object_id('[dbo].[DropProcedure]')  
		and OBJECTPROPERTY(id, 'IsProcedure') = 1 )
		drop procedure [dbo].DropProcedure
go

------------- helper functions/procedures -------------
create function IfProcExist(@name nvarchar(50)) returns int
as begin
	if exists ( select * from sysobjects where id = object_id(@name)  
		and OBJECTPROPERTY(id, 'IsProcedure') = 1 )
		return 1
	return 0
end
go

create procedure DropProcedure(@name nvarchar(50))
as begin 
	declare @sql nvarchar(100) = 'drop procedure ' + @name;
	exec(@sql);
	--drop procedure [dbo].InitDB
end
go

------------- database initialization -------------

if dbo.IfProcExist('[dbo].[InitDB]') = 1
	exec DropProcedure @name = '[dbo].[InitDB]'
go

--create procedure for dababase initializaiton
create procedure dbo.InitDB (@recordsNumber int) 
as
begin 
	delete from [Users]
	insert into [Users](Id, Name, BossId) values(1,'User1', NULL);
	declare @n int = 2;
	while @n <= @recordsNumber
	begin
		declare @bossId int = floor(1 + (rand())*(@n-1));
		insert into [Users](Id, [Name], BossId) values(@n,concat('User',@n), @bossId);
		set @n = @n + 1;
	end;
	--select * from [Users] order by BossId	
end
go 

exec InitDB @recordsNumber = 20;
go 


---------- delclare temporary table that contain employees and their bosses ----------
declare @EmployeesWithBosses table
(
	Emp_Id int,
	Emp_Name nvarchar(50),
	Boss_Id int,
	Boss_Name nvarchar(50)
);
insert into @EmployeesWithBosses
select
	emp.Id, emp.Name, emp.BossId, boss.Name
from [Users] as emp left join [Users] as boss on emp.BossId = boss.Id;

select * from @EmployeesWithBosses
go

---------- Declare temporary table that contains bosses and how many employees they supervise ----------
declare @Bosses table 
(
	Boss_Id int,
	Boss_Name nvarchar(50),
	Subordinates int
);
insert into @Bosses
select 
	boss.Id, boss.Name, count(*)
from [Users] as boss join [Users] as emp on emp.BossId = boss.Id
group by boss.Id, boss.Name;

select * from @Bosses;
go 


--------------- Create CTE to select whole hierarchy ordered by level ---------------
with BossesHierarchy(emp_id, emp_name, boss_id, boss_name, level) 
as (
	--anchor member definition
	select Id, Name, BossId, Name, 0 from [Users] where BossId is null
	union all
	--recursive member definition
	select 
		[Users].Id, 
		[Users].Name, 
		[Users].BossId, 
		BossesHierarchy.emp_name, 
		BossesHierarchy.level + 1 
	from [Users] join BossesHierarchy on [Users].BossId = BossesHierarchy.emp_id
)
select * from BossesHierarchy order by level


--------------- Create CTE to select all subordinates of certain user in hierarchy ---------------
declare @userId1 int = 5;
with BossesHierarchy(emp_id, emp_name, boss_id, boss_name, level) 
as (
	--anchor member definition
	--select Id, Name, BossId, Name, 0 from [Users] where BossId is null
	select Id, Name, BossId, Name,0 from [Users] where Id = @userId1
	union all
	--recursive member definition
	select 
		[Users].Id, 
		[Users].Name, 
		[Users].BossId, 
		BossesHierarchy.emp_name, 
		BossesHierarchy.level + 1 
	from [Users] join BossesHierarchy on [Users].BossId = BossesHierarchy.emp_id
)
select * from BossesHierarchy order by level

--------------- Create CTE to select all bosses of certain user in hierarchy ---------------
declare @userId2 int = 5;
with BossesHierarchy(emp_id, emp_name, boss_id, boss_name) 
as (
	--anchor member definition
	select Id, Name, BossId, Name from [Users] where Id = @userId2
	union all
	--recursive member definition
	select 
		[Users].Id, 
		[Users].Name, 
		[Users].BossId, 
		BossesHierarchy.emp_name
	from [Users] join BossesHierarchy on [Users].Id = BossesHierarchy.boss_id
)
select * from BossesHierarchy

