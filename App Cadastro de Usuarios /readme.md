
## [Requisito] PostgreSQL

Um pré-requisito bem importante para rodar o sistema de cadastro de usuários é a instalação e configuração do banco PostgreSQL no seu ambiente para o sistema rodar, então segue um passo a passo de como fazer isso antes de rodar o sistema:


> **Nota:** Estou usando um Ubuntu Desktop para rodar esse ambiente, pode ser que alguns comandos mudem coforme o seu sistema operacional


1 - Faça o download e instalação do PostgreSQL:

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

2 - Verifique se a instalação ocorreu de forma certa:

```bash
sudo systemctl status postgresql
```

3 - Por padrão a instalação cria um usuário chamado `postgres` vamos usar ele para acessar o psql e alterar a senha desse usuário:

```bash
sudo -i -u postgres
psql
```
4 - Dentro do `psql` use o seguinte comando para alterar a senha:

```bash
ALTER USER postgres PASSWORD 'digite_uma_senha';
```

5 - para sair do `psql` use `\q` ou `exit`;

6 - Adicione a string de conexão a variável `POSTGRES_DSN`:

```bash
export POSTGRES_DSN="postgresql://postgres:<senha>@localhost:5432/postgres"
```
Pronto seu banco PostgreSQL estará configurado da forma corretada para executar a aplicação!!!

## Como rodar o sistema de cadastro de usuários

1 - Faça o clone desse repositório em sua máquina para ter acesso ao código da aplicação

2 - Com o golang instalado na sua máquina execute o comando:
```bash
go run usuarios.go
```
