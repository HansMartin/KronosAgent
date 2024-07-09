From itsafeaturemythic/mythic_python_base:latest
RUN apt update
RUN apt install -y mingw-w64
RUN pip install requests
RUN curl https://nim-lang.org/choosenim/init.sh -sSf > $HOME/init.sh
RUN chmod +x $HOME/init.sh
RUN $HOME/init.sh -y
ENV PATH="${PATH}:/root/.nimble/bin"
RUN nimble -y install winim
RUN nimble -y install puppy
RUN nimble -y install nimcrypto

WORKDIR /Mythic/
CMD ["python3", "main.py"]
