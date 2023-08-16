FROM python:3.10

ADD ./src/main.py /app/main.py
ADD ./src/requirements.txt /app/requirements.txt
WORKDIR /app

RUN pip3 install -r requirements.txt

ENTRYPOINT ["faust","-A","main","worker","-l","info"]
