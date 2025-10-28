FROM public.ecr.aws/lambda/python:3.11

WORKDIR /var/task

COPY index.html app.py ./

CMD ["app.handler"]