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

create table if not exists audit_log (
	id		serial primary key,
	ts		timestamp with time zone default now(),
	username	varchar(128) default ''::character varying not null,
	sourceip	varchar(32) default ''::character varying not null,
	tag		integer,
	entry		varchar(1024) not null,

	foreign key (tag) references audit_types(id)
);

create table if not exists bigip_json (
        id              serial primary key,
        ts              timestamp with time zone default now(),
        uid             uuid unique,
        regkey          varchar(33) not null,
        content         jsonb not null,

        unique (ts,regkey)
);

create table if not exists hwplatforms (
        id              serial primary key,
        platform        varchar(16) unique,
        model           varchar(16),
        sku             varchar(24),

        unique (platform,model,sku)
);

create table if not exists tmossku (
        id              serial primary key,
        module          varchar(16) unique,
        sku             varchar(24)
);

--
-- Views
--

drop view all_audit_log;
create view all_audit_log as
	select audit_log.*,audit_types.description from audit_log, audit_types where audit_log.tag = audit_types.id;

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
	description	varchar(256),

	foreign key (archive_type) references archive_types(id)
);

drop view all_archives;
create view all_archives as
	select archives.id, archives.ts, archives.archive_type, archive_types.tag as archive_tag,
	archives.description as archive_description,
	archive_types.description as archive_types_description, archives.uid
	from archives,archive_types
	where archives.archive_type=archive_types.id;

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

drop view all_json_reports;
create view all_json_reports as
	select json_reports.id,json_reports.archive_uid,json_reports.ts,json_reports.typeid,
		json_types.tag,json_types.uri,json_types.description
	from json_reports, json_types
	where json_reports.typeid = json_types.id;

drop view all_contracts;
drop view all_keys;

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

        primary key (legal_contract,end_customer),
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
        hostname                        varchar(256) default '',
	machineid			varchar(64) default '',
        pool_reg_key                    integer,

        primary key (hostname,machineid,pool_reg_key),
        foreign key (pool_reg_key) references edw_pool_reg_keys(id)
);

create view all_contracts as
        select edw_customers.id as end_customer_id,edw_customers.end_customer_name,
                edw_contracts.id as edw_contracts_id,legal_contract,start_date,end_date,
                edw_salesorders.id as edw_salesorders_id,sales_order
        from edw_customers,edw_contracts,edw_salesorders,archive_to_contract
        where edw_salesorders.legal_contract_id = edw_contracts.id
                and edw_contracts.end_customer = edw_customers.id 
                and archive_to_contract.contract_id = edw_contracts.id;

create view all_keys as
select
    edw_customers.id as edw_customers_id,
    edw_customers.end_customer_name,
    edw_contracts.id as edw_contracts_id,
    edw_contracts.legal_contract,
    edw_contracts.start_date as legal_contract_start_date,
    edw_contracts.end_date as legal_contract_end_date,
    edw_salesorders.id as edw_salesorders_id,
    edw_salesorders.sales_order,
    edw_regkeys.id as edw_regkeys_id,
    edw_regkeys.regkey,
    edw_regkeys.serial_number,
    edw_pool_reg_keys.id as edw_pool_reg_keys_id,
    edw_pool_reg_keys.pool_reg_key,
    edw_ve_hostnames.id as edw_ve_hostnames_id,
    edw_ve_hostnames.hostname,
    edw_ve_hostnames.machineid
from
    edw_customers
full join
    edw_contracts
on
    edw_contracts.end_customer = edw_customers.id
    full join
        edw_salesorders
    on
        edw_salesorders.legal_contract_id = edw_contracts.id
        full join
            edw_regkeys
        on
            edw_regkeys.sales_order_id=edw_salesorders.id
            full join
                edw_pool_reg_keys
            on
                edw_pool_reg_keys.sales_order_id=edw_salesorders.id
                full join
                    edw_ve_hostnames
                on
                    edw_ve_hostnames.pool_reg_key=edw_pool_reg_keys.id;

drop view edw_ve_data;
create view edw_ve_data as
select
        edw_pool_reg_keys.pool_reg_key as regkey,
        edw_contracts.legal_contract as legal_contract_id,
        edw_salesorders.sales_order as sales_order,
        '' as serial_number,
        edw_customers.end_customer_name as end_customer_name,
        edw_customers.id as end_customer_id,
        edw_contracts.start_date as legal_contract_start_date,
        edw_contracts.end_date as legal_contract_end_date,
        edw_ve_hostnames.hostname as hostname,
	edw_ve_hostnames.machineid as machineid
from
        edw_customers,edw_contracts,edw_salesorders,edw_pool_reg_keys,edw_ve_hostnames
where
        edw_customers.id = edw_contracts.end_customer and
        edw_contracts.id = edw_salesorders.legal_contract_id and
        edw_salesorders.id = edw_pool_reg_keys.sales_order_id and
        edw_pool_reg_keys.id = edw_ve_hostnames.pool_reg_key;

drop view edw_hw_data;
create view edw_hw_data as
select
        edw_regkeys.regkey as regkey,
        edw_contracts.legal_contract as legal_contract_id,
        edw_salesorders.sales_order as sales_order,
        edw_regkeys.serial_number as serial_number,
        edw_customers.end_customer_name as end_customer_name,
        edw_customers.id as end_customer_id,
        edw_contracts.start_date as legal_contract_start_date,
        edw_contracts.end_date as legal_contract_end_date,
        '' as hostname
from
        edw_customers,edw_contracts,edw_salesorders,edw_regkeys
where
        edw_customers.id = edw_contracts.end_customer and
        edw_contracts.id = edw_salesorders.legal_contract_id and
        edw_salesorders.id = edw_regkeys.sales_order_id;

create table if not exists archive_to_contract (
	id		serial unique,
	archive_uid	uuid,
	contract_id	integer,

	primary key (archive_uid,contract_id),
	foreign key (archive_uid) references archives(uid),
	foreign key (contract_id) references edw_contracts(id)
);

create table if not exists sw_on_hw (
	id			serial unique,
	archive_uid		uuid,
	contract_id		integer,
	sku_prefix		varchar(4),
	rating_platform_module	varchar(32),
	as_of_date		varchar(16),
	quantity		integer,
	dss_create_time		varchar(32),
	trash_flag		boolean,
	trash_reason		varchar(256),

	primary key (archive_uid,contract_id,sku_prefix,rating_platform_module),
	foreign key (archive_uid) references archives(uid),
	foreign key (contract_id) references edw_contracts(id)
);

drop view all_sw_on_hw;
create view all_sw_on_hw as
select
	edw_customers.end_customer_name,sw_on_hw.archive_uid,edw_contracts.legal_contract,sw_on_hw.sku_prefix,
	sw_on_hw.rating_platform_module,sw_on_hw.as_of_date,
	sw_on_hw.quantity,sw_on_hw.dss_create_time,sw_on_hw.trash_flag,sw_on_hw.trash_reason
from
	sw_on_hw,edw_contracts,edw_customers
where
	sw_on_hw.contract_id=edw_contracts.id
	and edw_contracts.end_customer=edw_customers.id;

--
-- EDW data import
--
create table if not exists view_rpt_big_iq_ela_json_detail_licensing (
        legal_contract_id			varchar(128),
        image_instance_id			varchar(128),
        image_instance_sku			varchar(128),
        pool_name				varchar(128),
        billing_month_start_date		varchar(128),
        dim_billing_month_start_date_key	varchar(128),
        billing_month_end_date			varchar(128),
        dim_billing_month_end_date_key		varchar(128),
        list_price				varchar(128),
        pool_reg_key				varchar(128),
        pool_serial_num				varchar(128),
        hostname				varchar(128),
        grant_dt				varchar(128),
        dim_grant_date_key			varchar(128),
        revoke_dt				varchar(128),
        dim_revoke_date_key			varchar(128),
        duration_in_days			varchar(128),
        dim_end_customer_key			varchar(128),
        dim_bill_to_customer_key		varchar(128),
        dim_ship_to_customer_key		varchar(128),
        dim_supporting_reseller_customer_key	varchar(128),
        reduction_to_usage_amount		varchar(128),
        comments				varchar(1024),
        approved_by				varchar(128),
        dispute_reason				varchar(128),
        login					varchar(128),
        dispute_create_time			varchar(128),
	chargeback_tag				varchar(128)
);

create table if not exists view_rpt_ela_big_iq_clarify_serial_num (
        legal_contract_id		varchar(128),
        legal_contract_start_date       varchar(128),
        legal_contract_end_date		varchar(128),
        bill_to_customer_name		varchar(128),
        end_customer_name		varchar(128),
        sales_order			varchar(128),
        serial_number			varchar(128),
        part_number			varchar(128),
        feature_value			varchar(128),
        registrationkey			varchar(128)
);

create table if not exists view_user_entry_big_iq_ela_sizing (
        legal_contract_id	varchar(128),
        image_instance_sku	varchar(128),
        sku_quantity		varchar(128),
        login			varchar(128),
        dss_create_time		varchar(128)
);

--
-- General purpose views
--
drop view all_reports;
create view all_reports as
select
    archives.uid as archive_uid, archives.description as archive_description,
    json_types.id as json_type_id, json_types.description as json_type,
    json_reports.id as json_report_id, json_types.tag as json_report_tag, json_types.description as json_type_description
from
    json_types, json_reports, archives, archive_types
where
    json_reports.typeid = json_types.id and
    json_reports.archive_uid = archives.uid and
    archives.archive_type = archive_types.id
