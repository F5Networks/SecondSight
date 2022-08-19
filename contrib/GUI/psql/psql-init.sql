--
-- DB creation
--
-- drop database secondsight;
-- drop user secondsight;

create user secondsight with createdb password 'admin';
create database secondsight owner secondsight;
\c secondsight secondsight;

--
-- Schema definition
--
create table json_types (
	id		serial primary key unique,
	tag		varchar(64) default ''::character varying not null unique,
	uri		varchar(128) default ''::character varying not null,
	description 	varchar(128) default ''::character varying not null
);

create table audit_types (
	id		integer unique,
	tag		varchar(64) default ''::character varying not null primary key unique,
	description 	varchar(128) default ''::character varying not null
);

create table contract_types (
	id		integer unique,
	tag		varchar(64) default ''::character varying not null primary key unique,
	description 	varchar(128) default ''::character varying not null
);

create table config (
	name		varchar(128) primary key,
	value		varchar(4096) default ''::character varying not null
);

create table audit_log (
	id		serial primary key,
	ts		timestamp with time zone default now(),
	username	varchar(128) default ''::character varying not null,
	sourceip	varchar(32) default ''::character varying not null,
	tag		integer,
	entry		varchar(1024) not null,

	foreign key (tag) references audit_types(id)
);

create view all_audit_log as
	select audit_log.*,audit_types.description from audit_log, audit_types where audit_log.tag = audit_types.id;

create table contracts (
	id		serial unique,
	legalid		varchar(128) unique,
	contracttype	integer,
	description	varchar(256),

	primary key (legalid,contracttype),
	foreign key (contracttype) references contract_types(id)
);

create view all_contracts as
	select contracts.id, contracts.legalid, contracts.description, contract_types.tag, contract_types.description
	as contract_types_description
	from contracts, contract_types
	where contracts.contracttype = contract_types.id;

create table archive_types (
	id		integer unique,
	tag		varchar(64) default ''::character varying not null primary key unique,
	description 	varchar(128) default ''::character varying not null
);

create table archives (
	id		serial primary key unique,
	ts		timestamp with time zone default now(),
	archive_type	integer not null,
	uid		uuid unique,
	contract_id	integer,
	description	varchar(256),

	foreign key (archive_type) references archive_types(id),
	foreign key (contract_id) references contracts(id)
);

create view all_archives as
	select archives.id, archives.ts, archives.archive_type, archive_types.tag as archive_tag,
	archives.description as archive_description,
	archive_types.description as archive_types_description, archives.uid, archives.contract_id,
	contract_types.tag as contract_tag,contract_types.description as contract_description,
	contracts.legalid
	from archives,archive_types,contracts,contract_types
	where archives.contract_id=contracts.id
	and archives.archive_type=archive_types.id
	and contracts.contracttype=contract_types.id;

create table bigiq_files (
	id		serial primary key unique,
	ts		timestamp with time zone default now(),
	filename	varchar(128),
	tgzfile		bytea,
	archive_uid	uuid,

	foreign key (archive_uid) references archives(uid)
);

create table json_reports (
	id		serial primary key,
	ts		timestamp with time zone default now(),
	typeid		integer,
	content		jsonb,
	archive_uid	uuid,

	foreign key (typeid) references json_types(id),
	foreign key (archive_uid) references archives(uid)
);

create view all_json_reports as
	select json_reports.id,json_reports.archive_uid,json_reports.ts,json_reports.typeid,
		json_types.tag,json_types.uri,json_types.description
	from json_reports, json_types
	where json_reports.typeid = json_types.id;

--
-- General purpose views
--
create view all_reports as
select
    contracts.id as contract_id, contracts.legalid as contract_legalid,
    contract_types.tag as contract_type_tag, contract_types.description as contract_type_description,  
    archives.uid as archive_uid, archives.description as archive_description,
    json_types.id as json_type_id, json_types.description as json_type,
    json_reports.id as json_report_id, json_types.tag as json_report_tag, json_types.description as json_type_description
from
    json_types, json_reports, archives, archive_types, contracts, contract_types
where
    json_reports.typeid = json_types.id and
    json_reports.archive_uid = archives.uid and
    archives.archive_type = archive_types.id and
    archives.contract_id = contracts.id and
    contracts.contracttype = contract_types.id;

--
-- Default & builtin data
--
insert into config (name,value) values
('dataplane.address','http://nim.test.lab'),
('dataplane.type','NGINX Management Suite'),
('f5tt.helper.address','http://f5tt:5001'),
('f5tt.address','http://f5tt:5000');

insert into audit_types (id,tag,description) values
(100,'user.login','User login'),
(101,'user.logout','User logout'),
(200,'bigiq.upload','BIG-IQ offline tgz upload'),
(300,'nms.upload','NMS JSON report upload');

insert into contract_types (id,tag,description) values
(100,'contract.fcp','Flexible Consumption Program'),
(101,'contract.ela','Enterprise License Agreement');

insert into archive_types (id,tag,description) values
(100,'archive.bigiq','BIG-IQ Offline collection tgz file'),
(101,'archive.nms','NGINX full JSON');

insert into json_types (id,tag,uri,description) values
(100,'json.bigiq.full','/instances','BIG-IQ Full'),
(101,'json.bigiq.cve','/instances?type=CVE','BIG-IQ CVE'),
(102,'json.bigiq.cvebydevice','/instances?type=CVEbyDevice','BIG-IQ CVE by Device'),
(103,'json.bigiq.swonhw','/instances?type=SwOnHw','BIG-IQ Software on Hardware'),
(104,'json.bigiq.fullswonhw','/instances?type=fullSwOnHw','BIG-IQ Full Software on Hardware'),
(105,'json.bigiq.complete','/instances?type=complete','BIG-IQ Complete'),
(106,'json.bigiq.utilitybilling','/instances?type=utilityBilling','BIG-IQ Utility Billing'),
(200,'json.nms.full','/instances','NGINX Full'),
(201,'json.nms.cve','/instances?type=CVE','NGINX CVE'),
(202,'json.nms.timebased','/instances?type=timebased','NGINX Time-based')
