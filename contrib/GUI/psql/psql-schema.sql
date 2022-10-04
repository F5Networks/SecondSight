--
-- DB schema definition
--
create table if not exists json_types (
	id		serial primary key unique,
	tag		varchar(64) default ''::character varying not null unique,
	uri		varchar(128) default ''::character varying not null,
	description 	varchar(128) default ''::character varying not null
);

create table if not exists audit_types (
	id		integer unique,
	tag		varchar(64) default ''::character varying not null primary key unique,
	description 	varchar(128) default ''::character varying not null
);

create table if not exists contract_types (
	id		integer unique,
	tag		varchar(64) default ''::character varying not null primary key unique,
	description 	varchar(128) default ''::character varying not null
);

create table if not exists audit_log (
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

create table if not exists contracts (
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

create table if not exists archive_types (
	id		integer unique,
	tag		varchar(64) default ''::character varying not null primary key unique,
	description 	varchar(128) default ''::character varying not null
);

create table if not exists archives (
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

create table if not exists bigiq_files (
	id		serial primary key unique,
	ts		timestamp with time zone default now(),
	filename	varchar(128),
	tgzfile		bytea,
	archive_uid	uuid,

	foreign key (archive_uid) references archives(uid)
);

create table if not exists json_reports (
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

create table if not exists edw_customers (
        id                              serial unique,
        end_customer_name               varchar(256) primary key unique
);

create table if not exists edw_contracts (
        id                              serial unique,
        legal_contract                  varchar(64),
        start_date                      varchar(64),
        end_date                        varchar(64),
        end_customer                    integer,

        primary key (legal_contract),
        foreign key (end_customer) references edw_customers(id)
);

create table if not exists edw_salesorders (
        id                              serial unique,
        sales_order                     varchar(64),
        legal_contract_id               integer,

        primary key (sales_order),
        foreign key (legal_contract_id) references edw_contracts(id)
);

create table if not exists edw_regkeys (
        id                              serial unique,
        regkey                          varchar(33),
        serial_number                   varchar(64),
        sales_order_id                  integer,

        primary key (regkey),
        foreign key (sales_order_id) references edw_salesorders(id)
);

create table if not exists edw_pool_reg_keys (
        id                              serial unique,
        pool_reg_key                    varchar(33),
        sales_order_id                  integer,

        primary key (pool_reg_key),
        foreign key (sales_order_id) references edw_salesorders(id)
);

create table if not exists edw_ve_hostnames (
        id                              serial unique,
        hostname                        varchar(256),
        pool_reg_key                    integer,

        primary key (hostname,pool_reg_key),
        foreign key (pool_reg_key) references edw_pool_reg_keys(id)
);

create view edw_ve_data as
select
        edw_pool_reg_keys.pool_reg_key as regkey,
        edw_contracts.legal_contract as legal_contract_id,
        edw_salesorders.sales_order as sales_order,
        '' as serial_number,
        edw_customers.end_customer_name as end_customer_name,
        edw_contracts.start_date as legal_contract_start_date,
        edw_contracts.end_date as legal_contract_end_date,
        edw_ve_hostnames.hostname as hostname
from
        edw_customers,edw_contracts,edw_salesorders,edw_pool_reg_keys,edw_ve_hostnames
where
        edw_customers.id = edw_contracts.end_customer and    
        edw_contracts.id = edw_salesorders.legal_contract_id and
        edw_salesorders.id = edw_pool_reg_keys.sales_order_id and
        edw_pool_reg_keys.id = edw_ve_hostnames.pool_reg_key; 

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
