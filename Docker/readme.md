# Executar a app de usuários em golang via Dockerfile
 
 ## Requisitos:
 
 1. Realizar o download de todos os arquivos e salvar dentro de um diretório único;
 2. Ter o Docker instalado em sua maquina

## Como Executar a aplicação "conteinerizada" via Docker:

1 - Com todos os arquivos desse repositório em uma pasta separada execute o Dockerfile com o seguinte comando:

    docker build -t usuarios-go-app .

Assim criamos a nossa imagem da aplicação **"usuarios-go-app"** 

2 - Como tive algumas dificuldades em fazer o container da minha aplicação se conectar com o container do PostgreSQL, optei por criar uma rede a parte e colocar ambos nesse mesma rede, para criar a rede execute o seguinte comando

    docker network create <nome da rede>

3 - Agora com a rede criada vamos criar o nosso banco de dados no Docker, para realizar isso execute o seguinte comando abaixo:

    docker run --name <digite um nome para o container> --network <nome da sua rede> -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=<digite uma senha> -e POSTGRES_DB=cadastro_user_db -p 5432:5432 -d postgres:latest

4 - Com o banco de dados criado podemos agora subir o container da nossa aplicação, para realizar isso execute o seguinte comando:

    docker run --name usuarios-go-app \
           --network <nome da rede> \
           -p 8080:8080 \
           -e POSTGRES_DSN="postgres://postgres:<sua senha>@<nome do container do postgre>:5432/cadastro_user_db?sslmode=disable" \
           usuarios-go-app

5- Com isso você conseguira acessar a aplicação digitando no navegador o endereço de **localhost:8080**

