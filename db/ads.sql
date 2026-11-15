
-- advertiser statuses
drop table if exists adv_statuses;
create table adv_statuses
(
	statusId integer unsigned primary key not null,
	title varchar(32) not null
);
INSERT INTO adv_statuses (statusId, title) VALUES (0, 'not-approved');
INSERT INTO adv_statuses (statusId, title) VALUES (1, 'active');
INSERT INTO adv_statuses (statusId, title) VALUES (2, 'disabled');




-- advertisers
drop table if exists advertisers;
create table advertisers
(
	advertiserId integer unsigned primary key not null auto_increment,
	email varchar(128) not null, -- unique, used as login
	passwd varchar(32) not null,

	statusId int not null default 0, -- 0-not-approved, 1-active, 2-disabled

	name varchar(64) not null,
	company varchar(64) not null,
	address1 varchar(128) not null,
	address2 varchar(128) not null,
	city varchar(64) not null,
	stateId integer,
	state varchar(64),
	countryId integer not null,
	zip varchar(32) not null,
	phone varchar(64) not null,
	fax varchar(64) not null,
	urlAdv varchar(128) not null,
	description varchar(255) not null,

	registered datetime, -- when this record was created

	index advertisers_email(email)
);


---- advertisers payments history
--drop table if exists adv_payments;
--create table adv_payments
--(
--	advertiserId integer unsigned not null, -- FK
--	amount decimal(14,5) not null, -- +/- how much were paid to that advertiser
--	paid datetime not null,
--	notes varchar(255),
--  
--	index adv_payments_advertiserId(advertiserId)
--);




-- categories of campaigns
drop table if exists categories;
create table categories
(
	categoryId integer unsigned primary key not null auto_increment,
	title varchar(64)
);


INSERT INTO categories (categoryId, title) VALUES (1, 'Auctions');
INSERT INTO categories (categoryId, title) VALUES (2, 'Automotive');
INSERT INTO categories (categoryId, title) VALUES (3, 'Cash Advances');
INSERT INTO categories (categoryId, title) VALUES (4, 'Cellular');
INSERT INTO categories (categoryId, title) VALUES (5, 'Contests/Sweeps');
INSERT INTO categories (categoryId, title) VALUES (6, 'Credit');
INSERT INTO categories (categoryId, title) VALUES (7, 'Credit Cards');
INSERT INTO categories (categoryId, title) VALUES (8, 'Debt/Mortgage');
INSERT INTO categories (categoryId, title) VALUES (9, 'Education');
INSERT INTO categories (categoryId, title) VALUES (10, 'Electronics');
INSERT INTO categories (categoryId, title) VALUES (11, 'Food/Beverage');
INSERT INTO categories (categoryId, title) VALUES (12, 'Freebies');
INSERT INTO categories (categoryId, title) VALUES (13, 'Gift Cards');
INSERT INTO categories (categoryId, title) VALUES (14, 'Health/Beauty');
INSERT INTO categories (categoryId, title) VALUES (15, 'Health/Life Insurance');
INSERT INTO categories (categoryId, title) VALUES (16, 'Holiday Products');
INSERT INTO categories (categoryId, title) VALUES (17, 'Ink');
INSERT INTO categories (categoryId, title) VALUES (18, 'Membership Clubs');
INSERT INTO categories (categoryId, title) VALUES (19, 'Money Making');
INSERT INTO categories (categoryId, title) VALUES (20, 'Music/Video Packs');
INSERT INTO categories (categoryId, title) VALUES (21, 'Not Specified');
INSERT INTO categories (categoryId, title) VALUES (22, 'Pets');
INSERT INTO categories (categoryId, title) VALUES (23, 'Real Estate');
INSERT INTO categories (categoryId, title) VALUES (24, 'Romance/Dating');
INSERT INTO categories (categoryId, title) VALUES (25, 'Smoking');
INSERT INTO categories (categoryId, title) VALUES (26, 'Software');
INSERT INTO categories (categoryId, title) VALUES (27, 'Special');
INSERT INTO categories (categoryId, title) VALUES (28, 'Sports');
INSERT INTO categories (categoryId, title) VALUES (29, 'Taxes');
INSERT INTO categories (categoryId, title) VALUES (30, 'Toys');




-- fake domains used for links
drop table if exists domains;
create table domains
(
	domainId integer unsigned primary key not null auto_increment,
	domain varchar(64)
);
	
INSERT INTO domains (domain) VALUES ('www.adsbucks.com');





-- campaign types
drop table if exists cam_types;
create table cam_types
(
	typeId integer unsigned primary key not null,
	title varchar(32) not null
);
INSERT INTO cam_types (typeId, title) VALUES (0, 'CPA (per sale)');
INSERT INTO cam_types (typeId, title) VALUES (1, 'CPC (per click)');
INSERT INTO cam_types (typeId, title) VALUES (2, 'CPM (per 1000 views)');




-- campaign statuses
drop table if exists cam_statuses;
create table cam_statuses
(
	statusId integer unsigned primary key not null,
	title varchar(32) not null
);
INSERT INTO cam_statuses (statusId, title) VALUES (0, 'not-approved');
INSERT INTO cam_statuses (statusId, title) VALUES (1, 'active');
INSERT INTO cam_statuses (statusId, title) VALUES (2, 'disabled');
INSERT INTO cam_statuses (statusId, title) VALUES (3, 'new values to approve');




-- campaigns
drop table if exists campaigns;
create table campaigns
(
	campaignId integer unsigned primary key not null auto_increment,
	advertiserId integer unsigned not null, -- FK
	name varchar(64) not null,

	categoryId integer unsigned not null, -- FK
	domainId integer unsigned not null, -- FK

	typeId integer not null default 1, -- 0-CPA (per sale), 1-CPC (per click), 2-CPM (per 1000 views)

	price decimal(14,5) not null default 0.0,		-- price or for #2-nd type (for 1000 views) the price for 1000 view-actions
	priceNew decimal(14,5),
	priceCPM decimal(14,5) not null default 0.0,	-- price for one view-action; it has sence for #2-nd type (for 1000 views) only
	priceNewCPM decimal(14,5),

	pricePub decimal(14,5) not null default 0.0,		-- publisher price or for #2-nd type (for 1000 views) the price for 1000 view-actions
	pricePubCPM decimal(14,5) not null default 0.0,		-- publisher price for one view-action; it has sence for #2-nd type (for 1000 views) only

	account decimal(14, 5) not null default 0, -- adv. account should be > 0 to be active

	urlActual varchar(128), -- specified url provided by advertiser
	urlNew varchar(128), -- specified url provided by advertiser

	statusId integer not null default 0, -- 0-not-approved, 1-active, 2-disabled, 3-active but has new values to approve


	suppFile varchar(128),	-- not null if there is some such file uploaded
							-- it should be saved in some specified folder by name: {campaignId}.ext

	subsId integer unsigned null, -- FK; campaignId that would be treated as this one or null

	registered datetime, -- when this record was created
	updated datetime, -- when this record was updated last time

	index campaigns_subsId(subsId),
	index campaigns_advertiserId(advertiserId),
	index campaigns_categoryId(categoryId),
	index campaigns_domainId(domainId)
	
);

-- campaigns payments history
drop table if exists cam_payments;
create table cam_payments
(
	campaignId integer unsigned not null, -- FK
	amount decimal(14,5) not null, -- +/- how much were get from that campaign
	paid datetime not null,
	notes varchar(255),

	index cam_payments_campaignId(campaignId)
);



-- creative statuses
drop table if exists cre_statuses;
create table cre_statuses
(
	statusId integer unsigned primary key not null,
	title varchar(32) not null
);
INSERT INTO cre_statuses (statusId, title) VALUES (0, 'not-approved');
INSERT INTO cre_statuses (statusId, title) VALUES (1, 'active');
INSERT INTO cre_statuses (statusId, title) VALUES (2, 'disables');
INSERT INTO cre_statuses (statusId, title) VALUES (3, 'new values to approve');


-- creative types
drop table if exists cre_types;
create table cre_types
(
	typeId integer unsigned primary key not null,
	title varchar(32) not null
);
INSERT INTO cre_types (typeId, title) VALUES (1, 'Plain text');
INSERT INTO cre_types (typeId, title) VALUES (2, 'HTML');


	

-- creatives
drop table if exists creatives;
create table creatives
(
	creativeId integer unsigned primary key not null auto_increment,
	campaignId integer unsigned not null, -- FK
	typeId integer not null default 1, -- 1-Plain Text, 2-HTML

	body text, -- current to use by publichers
	bodyNew text, -- new one just added by advertiser

	statusId integer not null default 0,	-- 0-not approved
											-- 1-text from bodyNew was copied to body by admin and approved as well
											-- 3-active but has new values to approve
	registered datetime, -- when this record was created
	updated datetime, -- when this record was updated last time

	index creatives_campaignId(campaignId)
);



-- creative images
drop table if exists cre_imgs;
create table cre_imgs
(
	imgId integer unsigned primary key not null auto_increment,
	creativeId integer unsigned not null,
	name varchar(128) not null
);



-- publisher statuses
drop table if exists pub_statuses;
create table pub_statuses
(
	statusId integer unsigned primary key not null,
	title varchar(32) not null
);
INSERT INTO pub_statuses (statusId, title) VALUES (0, 'not-approved');
INSERT INTO pub_statuses (statusId, title) VALUES (1, 'active');
INSERT INTO pub_statuses (statusId, title) VALUES (2, 'disabled');


-- publisher campaigns (specified prices)
drop table if exists pub_cams;
create table pub_cams
(
	publisherId integer unsigned not null,
	campaignId integer unsigned not null,

	price decimal(14,5) not null default 0.0,		-- publisher price or for #2-nd type (for 1000 views) the price for 1000 view-actions
	priceCPM decimal(14,5) not null default 0.0,	-- price for one view-action; it has sence for #2-nd type (for 1000 views) only

	PRIMARY KEY pub_cams_pk (publisherId, campaignId)
);

-- publishers
drop table if exists publishers;
create table publishers
(
	publisherId integer unsigned primary key not null auto_increment,

	email varchar(128) not null, -- unique, used as login
	passwd varchar(32) not null,

	statusId int not null default 0, -- 0-not-approved, 1-active, 2-disabled

	name varchar(64) not null,
	company varchar(64) not null,
	address1 varchar(128) not null,
	address2 varchar(128) not null,
	city varchar(64) not null,
	stateId integer,
	state varchar(64),
	countryId integer not null,
	zip varchar(32) not null,
	phone varchar(64) not null,
	fax varchar(64) not null,
	urlPub varchar(128) not null,
	description varchar(255) not null,

	account decimal(14, 5) not null default 0, -- adv. account should be > 0 to be active

	registered datetime, -- when this record was created

	index publishers_email(email)
);


-- publishers payments history
drop table if exists pub_payments;
create table pub_payments
(
	publisherId integer unsigned not null, -- FK
	amount decimal(14,5) not null, -- +/- how much were paid to that publisher
	paid datetime not null,
	notes varchar(255),

	index adv_payments_publisherId(publisherId)
);


-- agents
drop table if exists agents;
create table agents
(
	agentId integer unsigned primary key not null auto_increment,
	agent varchar(255) not null
);


-- saleclicks
drop table if exists saleclicks;
create table saleclicks
(
	publisherId integer unsigned not null,
	campaignId integer unsigned not null,
	subId integer unsigned,
	ip varchar(32) not null,
	agentId integer unsigned not null,

	done date not null, -- date of the click

	counter bigint unsigned not null default 0,

	PRIMARY KEY pub_cams_pk (campaignId, ip, agentId, publisherId)
);


-- actions
drop table if exists actions;
create table actions
(
	publisherId integer unsigned not null, -- FK
	campaignId integer unsigned not null, -- FK
	subId integer unsigned, -- 
	done date not null, -- date of the click
	price decimal(14,5) not null default 0.0, -- actual price for publisher

	views bigint unsigned not null default 0,
	clicks bigint unsigned not null default 0,
	sales bigint unsigned not null default 0,
	
	index actions_done(done),
	index actions_publisherId(publisherId, subId),
	index actions_campaignId(campaignId)
);


-- BEGIN TRANSACTION
-- if there is a click then:
--		if there is such record already exists then just UPDATE counter=counter+1
--		else INSERT (counter=1)
-- COMMIT TRANSACTION
-- or maybe just use MySQL to make all things faster?




-- admin logins
drop table if exists admins;
create table admins
(
	adminId integer unsigned primary key not null auto_increment,
	login varchar(32),
	passwd varchar(32)
);

insert into admins (login, passwd) values ('testadmin', 'test_password');


-- allow or deny specified area for specified admin
drop table if exists admin_grants;
create table admin_grants
(
	adminId integer unsigned not null, -- FK
	grantId integer unsigned not null -- FK
);


insert into admin_grants (adminId, grantId) values (1, 1);
insert into admin_grants (adminId, grantId) values (1, 2);
insert into admin_grants (adminId, grantId) values (1, 3);
insert into admin_grants (adminId, grantId) values (1, 4);
insert into admin_grants (adminId, grantId) values (1, 5);
insert into admin_grants (adminId, grantId) values (1, 6);


-- the areas of admin interface that may be allowed of denied for specified admin in admin_grants table
drop table if exists grants;
create table grants
(
	grantId integer unsigned primary key not null auto_increment,
	title varchar(64)
);

INSERT INTO grants (title) VALUES ('Advertisers');
INSERT INTO grants (title) VALUES ('Publishers');
INSERT INTO grants (title) VALUES ('Reports');
INSERT INTO grants (title) VALUES ('Admins');
INSERT INTO grants (title) VALUES ('Domains');
INSERT INTO grants (title) VALUES ('Options');


-- options table. there should be only one record.
drop table if exists options;
create table options
(
	defaultDomainId integer not null
);

INSERT INTO options (defaultDomainId) VALUES (1);

