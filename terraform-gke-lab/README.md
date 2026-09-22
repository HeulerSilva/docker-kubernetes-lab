# GKE com Terraform — do cluster local ao Kubernetes gerenciado na nuvem 🚀

<p align="left">
  <img src="https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform" />
  <img src="https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white" alt="Google Cloud" />
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Kubernetes" />
  <img src="https://img.shields.io/badge/status-conclu%C3%ADdo%20%E2%9C%85-brightgreen?style=for-the-badge" alt="Status: concluído" />
</p>

## Sobre este projeto

Depois de montar meus labs de Terraform na AWS e na Azure, e de rodar
Kubernetes localmente com `kind` (repositório `docker-kubernetes-lab`),
resolvi fechar a trinca de nuvens indo pro Google Cloud — e dessa vez com
Kubernetes gerenciado de verdade (GKE), não só container local.

No meu lab local eu sempre esbarrava na mesma limitação: um `Service` do
tipo `LoadBalancer` nunca sai do estado `<pending>`, porque não existe um
balanceador de carga de verdade rodando na minha máquina. A motivação deste
projeto era ver esse mesmo manifesto rodando num cluster GKE real, com um
IP público de verdade. Levou duas tentativas (a sessão de 25 minutos do lab
expirou no meio da primeira), mas na segunda o ciclo fechou por completo —
o relato abaixo mostra os dois caminhos, obstáculos incluídos.

## 🎯 Resultado final

**`EXTERNAL-IP` público de verdade, servindo nginx.** Cluster
`gke-aula-infra`, projeto temporário `qwiklabs-gcp-03-ff9f2ef8a2b5`, zona
`asia-east1-a`:

```
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
aula-nginx-lb LoadBalancer   34.118.237.165  34.80.129.180   80:30368/TCP   46s
```

`http://34.80.129.180` respondendo no navegador com a página padrão do
nginx — exatamente o problema que o `kind` local nunca resolvia:

![Página "Welcome to nginx!" servida pelo EXTERNAL-IP do LoadBalancer](./assets/external-ip.png)

## 🏗️ O que este Terraform provisiona

- Um cluster GKE **zonal** (`gke-aula-infra`), numa zona liberada pela
  política do projeto temporário do lab — **variável a cada sessão nova**
  (nas duas tentativas documentadas aqui foi `us-west1-a` e depois
  `asia-east1-a`; ver obstáculo 4).
- Um node pool próprio, com 2 nós preemptíveis (`e2-medium`) e escopos
  OAuth explícitos (`logging.write`, `monitoring`, `cloud-platform`).
- Ativação da API `container.googleapis.com`.

Não cria VPC, subnet nem service account dedicadas — e isso não foi por
escolha de design, foi uma restrição do ambiente onde rodei (explico no
próximo tópico). Cluster usa a rede `default` do projeto e a service
account padrão de computação.

## 🧭 Obstáculos reais (e como contornei cada um)

**1. Faturamento pessoal pede autorização de R$ 200 no cartão.** Ao tentar
ativar minha conta GCP pessoal, mesmo pra usar o crédito de teste
gratuito, o Google exige uma autorização de pelo menos R$ 200 — uma
barreira real pra quem está estudando e não tem essa folga disponível no
momento. Resolvi usando o **Google Cloud Skills Boost**, com o laboratório
oficial "Google Kubernetes Engine: Qwik Start" (GSP100): ele fornece um
projeto GCP temporário já provisionado, sem pedir cartão nem conta
pessoal. Os créditos pra rodar o lab vieram do **Google Developer
Program** (nível gratuito "Standard"), que libera 35 créditos de
aprendizado por mês automaticamente — o lab custou só 1 desses créditos.

**2. O Cloud Shell nem sempre vem com o Terraform pronto pra uso.** Na
primeira tentativa, o pacote já estava instalado, mas o comando
`terraform` apontava pra um script interno do Google
(`/google/bin/terraform`) que só mostra instruções de instalação —
resolvido com `alias terraform=/usr/bin/terraform`. Numa sessão de lab
mais nova (projeto temporário diferente), o Terraform nem estava
instalado, e `sudo apt-get install terraform` falhava com
`E: Unable to locate package terraform`, porque o repositório oficial da
HashiCorp não vem configurado por padrão. Resolvi adicionando o
repositório manualmente antes de instalar:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
```

**3. A conta temporária do lab não tem permissão de IAM pra criar VPC nem
service account customizadas.** Minha primeira versão do `main.tf` (fiel à
estrutura do material da aula, com VPC dedicada, subnet e service account
próprias) falhou com `403: compute.networks.create` e
`403: iam.serviceAccounts.create`. Reescrevi pra usar a rede `default` do
projeto e a service account padrão — é a versão que está neste repositório.

**4. A política de organização que restringe a região não é fixa — muda a
cada sessão nova do lab.** Cada clique em "Start" sobe um projeto
temporário diferente, e o Google atribui uma lista própria de
`allowedValues` pra `constraints/gcp.resourceLocations`. Na primeira
tentativa a zona liberada era `us-west1-a`, descoberta pelo formulário de
criação de cluster no Console (a conta do lab não tinha permissão de
consultar a política direto). Na tentativa que finalmente concluiu,
`us-west1-a` foi rejeitada de novo — mas dessa vez consegui consultar a
política diretamente:

```bash
gcloud resource-manager org-policies describe constraints/gcp.resourceLocations --project=<PROJECT_ID> --effective
```

A resposta veio com uma mistura de grupos de multi-região (`us`, `eu`,
`global`, `aws-*`, `azure-*`) e zonas específicas de verdade — só essas
últimas servem pra um cluster GKE zonal. Da lista, as únicas no formato
`regiao-letra` eram `asia-east1-a`, `asia-east1-b` e `asia-east1-c`.
Apliquei de novo passando `-var="zone=asia-east1-a"`, sem precisar editar
o `main.tf`.

**5. A sessão do lab expirou antes do último passo — na primeira
tentativa.** Com os obstáculos 1 a 4 resolvidos, o `terraform apply`
completou: cluster criado, 2 nós em `Ready`, `kubectl` conectado. Restava
aplicar o manifesto da aplicação, mas a sessão de 25 minutos encerrou
nesse meio-tempo (o Google desativa a conta temporária e destrói o
projeto inteiro automaticamente). Não deu tempo de rodar o
`kubectl apply -f k8s/app.yaml` nem capturar o IP público — o motivo de eu
ter voltado numa sessão nova pra fechar o ciclo, o que gerou o obstáculo
abaixo.

**6. Colar um `cat <<EOF ... EOF` grande no terminal do Cloud Shell
corrompe o arquivo.** Ao colar o `main.tf` inteiro de uma vez via heredoc,
o terminal perdeu linhas no meio do conteúdo — é uma limitação conhecida
do paste multi-linha do Cloud Shell, não algo que dá pra contornar só
diminuindo o tamanho do bloco. A solução foi colar o conteúdo como base64
numa única linha:

```bash
echo "<conteúdo em base64>" | base64 -d > main.tf
```

Paste de uma linha só não sofre o mesmo problema.

## 🎉 O que ficou provado

Na segunda sessão do lab, o ciclo fechou por completo:

- `terraform init` e `terraform apply` concluídos com sucesso, já na zona
  certa (`asia-east1-a`): `Apply complete! Resources: 2 added, 0 changed,
  0 destroyed.`
- Cluster `gke-aula-infra` visível e saudável no Console (`asia-east1-a`,
  2 nós, 100% healthy, custo estimado `$0.00/month` por rodar em nós
  preemptíveis dentro do crédito do lab).

  ![Cluster gke-aula-infra saudável no Console do Google Cloud](./assets/kubernetes-cluster.png)

- `kubectl get nodes` com os 2 nós em `Ready`, versão
  `v1.35.8-gke.1036000`, confirmando que o `kubectl` local conectou
  corretamente ao cluster remoto.
- `kubectl apply -f k8s/app.yaml` criando o `Deployment` (2 réplicas) e o
  `Service` sem erro:

  ```
  deployment.apps/aula-nginx created
  service/aula-nginx-lb created
  ```

  ![Terminal do Cloud Shell rodando terraform apply, kubectl e o EXTERNAL-IP saindo do pending](./assets/cloud-shell.png)

- O `Service` do tipo `LoadBalancer` saiu do `<pending>` e ganhou um
  `EXTERNAL-IP` público de verdade — o problema original que motivou todo
  o projeto, resolvido (print e detalhes na seção **Resultado final**
  acima).

## 🔁 Como reproduzir (para uma próxima tentativa)

### 0. Garantir crédito gratuito pro lab

1. Entro em **developers.google.com/program** e me cadastro no nível
   gratuito "Standard" (sem cartão).
2. Confirmo em "Benefícios" que os 35 créditos mensais do Google Skills já
   aparecem liberados.
3. Procuro o lab **"Google Kubernetes Engine: Qwik Start"** (ID `GSP100`)
   no catálogo em [skills.google](https://www.skills.google/focuses/878?parent=catalog).

### 1. Abrir o lab

1. Clico em **Start** na página do lab — o cronômetro de 25 minutos começa
   aqui.
2. O lab abre uma janela anônima com credenciais temporárias
   (`student-01-...@qwiklabs.net`) — não uso minha conta pessoal.
3. Abro o **Cloud Shell** (ícone de terminal no topo do Console).

### 2. Garantir o Terraform

```bash
which -a terraform
```

Se só aparecer `/google/bin/terraform`, o pacote não está instalado —
adiciona o repositório da HashiCorp antes (obstáculo 2 acima) e instala com
`sudo apt-get install -y terraform`. Se já existir um `/usr/bin/terraform`
de verdade, só cria o alias:

```bash
alias terraform=/usr/bin/terraform
mkdir -p ~/gke-aula/k8s
cd ~/gke-aula
```

> ⚠️ **Dica:** evite colar arquivos grandes no terminal com
> `cat <<EOF`. O paste multi-linha do Cloud Shell pode corromper o
> conteúdo (obstáculo 6). Prefira colar como base64 numa linha só, ou usar
> o **Open Editor** do próprio Cloud Shell.

### 3. Descobrir a zona liberada

```bash
gcloud resource-manager org-policies describe constraints/gcp.resourceLocations --project=$(gcloud config get-value project) --effective
```

Procura na lista uma zona no formato `regiao-letra` (ex: `asia-east1-a`).
Se der `PERMISSION_DENIED`, abre o formulário de criação de cluster no
Console — o dropdown de zona só mostra as opções permitidas — sem clicar
em criar.

### 4. Terraform

```bash
terraform init
terraform apply -auto-approve -var="zone=<ZONA_LIBERADA>"
```

Leva de 3 a 6 minutos.

### 5. Conectar o kubectl

```bash
gcloud container clusters get-credentials gke-aula-infra --zone <ZONA_LIBERADA>
kubectl get nodes
```

### 6. Aplicar a aplicação e ver o EXTERNAL-IP sair do pending

```bash
kubectl apply -f k8s/app.yaml
kubectl get service aula-nginx-lb --watch
```

Assim que o `EXTERNAL-IP` vira um IP público, abro `http://<EXTERNAL-IP>`
no navegador pra confirmar que o nginx responde.

## 🧹 Destruir tudo (assim que terminar)

```bash
kubectl delete -f k8s/app.yaml
terraform destroy -auto-approve
```

O timer do lab é curto (25 min) e o Google já destrói o projeto inteiro
sozinho quando a sessão expira — mas rodar o destroy antes disso é a
prática correta, mesma disciplina que uso no meu lab de Azure.

## 🛠️ Stack

Terraform · Google Kubernetes Engine (GKE) · Google Cloud Skills Boost ·
Google Developer Program · kubectl · nginx
