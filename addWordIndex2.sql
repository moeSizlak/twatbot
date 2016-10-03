CREATE INDEX "W1Nick" ON "WORDS1" ("Nick");
CREATE INDEX "W1Word1Nick" ON "WORDS1" ("Word1","Nick");
CREATE INDEX "W1Word1Word2" ON "WORDS1" ("Word1","Word2");
CREATE INDEX "W1Word1" ON "WORDS1" ("Word1");
CREATE INDEX "W1Word2Nick" ON "WORDS1" ("Word2","Nick");
CREATE INDEX "W1Word2" ON "WORDS1" ("Word2");
CREATE INDEX "W1Word1Word2Nick" ON "WORDS1" ("Word1","Word2","Nick");


CREATE INDEX "W2Nick" ON "WORDS2" ("Nick");
CREATE INDEX "W2Word1Word2Nick" ON "WORDS2" ("Word1","Word2","Nick");
CREATE INDEX "W2Word1Word2Word3" ON "WORDS2" ("Word1","Word2","Word3");
CREATE INDEX "W2Word1Word2" ON "WORDS2" ("Word1","Word2");
CREATE INDEX "W2Word3Nick" ON "WORDS2" ("Word3","Nick");
CREATE INDEX "W2Word3Word2Nick" ON "WORDS2" ("Word3","Word2","Nick");
CREATE INDEX "W2Word3Word2" ON "WORDS2" ("Word3","Word2");
CREATE INDEX "W2Word3" ON "WORDS2" ("Word3");
