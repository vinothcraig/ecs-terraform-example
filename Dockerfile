FROM python:3.9-slim 
RUN apt update -y
RUN apt install sudo -y
RUN apt-get clean && \
echo myuser ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/myuser && \
chmod 0440 /etc/sudoers.d/myuser && \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/*
RUN mkdir /app
WORKDIR /app
RUN useradd myuser
USER myuser
COPY . /app
RUN sudo chown -R myuser /app
RUN sudo pip3 install poetry
RUN sudo poetry install
RUN sudo poetry run python manage.py makemigrations
RUN sudo poetry run python manage.py migrate
EXPOSE 8000

ENTRYPOINT ["/bin/sh"]
CMD ["./entry.sh"]

