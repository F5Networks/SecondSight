--
-- Default & builtin data
--
insert into audit_types (id,tag,description) values
(100,'user.login','User login'),
(101,'user.logout','User logout'),
(200,'bigiq.upload','BIG-IQ offline tgz upload'),
(300,'nms.upload','NMS JSON report upload');

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
(202,'json.nms.timebased','/instances?type=timebased','NGINX Time-based');

insert into edw_customers values
(0,'Not available');

insert into edw_contracts values
(0,'Not available','','',0);
