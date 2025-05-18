
## [Requisito] PostgreSQL

Um pré-requisito bem importante para rodar o sistema de cadastro de usurios é a instalação e configuração do banco PostgreSQL no seu ambiente para o sistema rodar, então segue um passo a passo de como fazer isso antes de rodar o sistema:


> **Nota:** Estou usando um Ubunto Desktop para rodar esse ambiente, pode ser que alguns comandos mudem coforme o seu sistema operacional


1 - Faça o download e instalação do PostgreSQL:

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

2 - Verifique se a instalação ocorreu de forma certa:

```bash
sudo systemctl status postgresql
```

3 - Por padrão a instalação cria um usuario chamado `postgres` vamos usar ele para acessar o psql e alterar a senha desse usuario:

```bash
sudo -i -u postgres
psql
```
4 - Dentro do `psql` use o seguinte comando para alterar a senha:

```bash
ALTER USER postgres PASSWORD 'digite_uma_senha';
```

5 - para sair do `psql` use `\q` ou `exit`;

6 - Adicione a string de conexão a variavel `POSTGRES_DSN`:

```bash
export POSTGRES_DSN="postgresql://postgres:<senha>@localhost:5432/postgres"
```
Pronto seu banco PostgreSQL estara configurado da forma corretada para executar a aplicação!!!

## Como rodar o sistema de cadastro de usuarios

1 - Faça o clone desse repositorio em sua maquina para ter acesso ao codigo da aplicação

2 - Com o golang instalado na sua maquina execute o comando:
```bash
go run usuarios.go
```
