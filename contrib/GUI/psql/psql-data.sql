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

-- https://support.f5.com/csp/article/K4309
insert into hwplatforms values
(1,'D110','7250','F5-BIG-7250'),
(2,'D113','10200','F5-BIG-10200'),
(3,'C113','4200','F5-BIG-4200'),
(4,'C109','5200','F5-BIG-5200'),
(5,'D116','I15800','F5-BIG-I15800'),
(6,'C124','I11800','F5-BIG-I11800-DS'),
(7,'C123','I11800','F5-BIG-I11800'),
--(8,'','I10800','F5-BIG-I10800-D'),
(9,'C116','I10800','F5-BIG-I10800'),
(10,'C126','I7820-DF','F5-BIG-I7820-DF'),
--(11,'','I7800','F5-BIG-I7800-D'),
(12,'C118','I7800','F5-BIG-I7800'),
(13,'C125','I5820-DF','F5-BIG-I5820-DF'),
(14,'C119','I5800','F5-BIG-I5800'),
(15,'C115','I4800','F5-BIG-I4800'),
(16,'C117','I2800','F5-BIG-I2800'),
--(17,'','C4800','F5-VPR-C4800-DCN'),
(18,'A109','B2100','F5-VPR-B2100'),
(19,'A113','B2150','F5-VPR-B2150'),
(20,'A112','B2250','F5-VPR-B2250'),
(21,'A114','B4450','F5-VPR-B4450N'),
(22,'F100','C2400','F5-VPR-C2400-AC'),
(23,'F101','C2400','F5-VPR-C2400-AC'),
--(24,'','C2400','F5-VPR-C2400-ACT'),
(25,'J102','C4480','F5-VPR-C4480-AC'),
--(26,'','C4480','F5-VPR-C4480-DCN'),
(27,'S100','C4800','F5-VPR-C4800-AC'),
(28,'S101','C4800','F5-VPR-C4800-AC'),
(29,'Z100','VE','F5-VE'),
(30,'Z101','VE-VCMP','F5-VE-VCMP');

insert into tmossku values (1,'gtm','DNS');
insert into tmossku values (2,'sslo','SSLO');
insert into tmossku values (3,'apm','APM');
insert into tmossku values (4,'cgnat','CGNAT');
insert into tmossku values (5,'ltm','LTM');
insert into tmossku values (6,'avr','AVR');
insert into tmossku values (7,'fps','');
insert into tmossku values (8,'dos','');
insert into tmossku values (9,'lc','');
insert into tmossku values (10,'pem','PEM');
insert into tmossku values (11,'urldb','');
insert into tmossku values (12,'swg','');
insert into tmossku values (13,'asm','AWF');
insert into tmossku values (14,'afm','AFM');
insert into tmossku values (15,'ilx','');
insert into tmossku values (16,'vcmp','');
insert into tmossku values (17,'tam','');
