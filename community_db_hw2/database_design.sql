create schema community_database;
use community_database;

create table user(
user_id char(15) primary key,
user_name char(20) unique,
user_password char(20),
user_role char(10)
);
alter table user
add unique(user_name);

#添加用户头像
ALTER TABLE user
ADD COLUMN avatar_url VARCHAR(255) DEFAULT NULL COMMENT '用户头像URL';
ALTER TABLE community_database.user MODIFY COLUMN user_password VARCHAR(255) NOT NULL;

#添加管理员信息
insert into user
values('admin1', 'admin1', 'admin1','admin', null);


create table section(
section_id char(15) primary key,
section_name char(20),
section_description char(200)
);

create table post(
post_id char(15) primary key,
post_name char(20),
post_content char(200),
poster_id char(15),
section_id_in char(15),
number_likes int,
create_date date,
foreign key(poster_id) references user(user_id),
foreign key(section_id_in) references section(section_id)
);
alter table post
add number_comments int;

create table comments(
comment_id char(15) primary key,
commenter_id char(15),
post_id_in char(15),
comment_content char(200),
comment_date date,
foreign key(commenter_id) references user(user_id),
foreign key(post_id_in) references post(post_id)
);

create table likes(
user_id_like char(15),
post_id_liked char(15),
primary key(user_id_like, post_id_liked)
);

create table report(
report_id char(15) primary key,
reporter_id char(15),
reported_post_id char(15),
report_reason char(200),
report_status int,
foreign key(reporter_id) references user(user_id),
foreign key(reported_post_id) references post(post_id)
);
