alter table WORDS1 ADD  INDEX Nick (Nick);
alter table WORDS1 ADD  INDEX Word1Nick (Word1,Nick);
alter table WORDS1 ADD  INDEX Word1Word2 (Word1,Word2);
alter table WORDS1 ADD  INDEX Word1 (Word1);
alter table WORDS1 ADD  INDEX Word2Nick (Word2,Nick);
alter table WORDS1 ADD  INDEX Word2 (Word2);
alter table WORDS1 ADD  INDEX Word1Word2Nick (Word1,Word2,Nick);


alter table WORDS2 ADD  INDEX Nick (Nick);
alter table WORDS2 ADD  INDEX Word1Word2Nick (Word1,Word2,Nick);
alter table WORDS2 ADD  INDEX Word1Word2Word3 (Word1,Word2,Word3);
alter table WORDS2 ADD  INDEX Word1Word2 (Word1,Word2);
alter table WORDS2 ADD  INDEX Word3Nick (Word3,Nick);
alter table WORDS2 ADD  INDEX Word3Word2Nick (Word3,Word2,Nick);
alter table WORDS2 ADD  INDEX Word3Word2 (Word3,Word2);
alter table WORDS2 ADD  INDEX Word3 (Word3);
