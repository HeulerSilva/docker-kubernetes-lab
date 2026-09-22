# GKE com Terraform — do cluster local ao Kubernetes gerenciado na nuvem

## Sobre este projeto

Depois de montar meus labs de Terraform na AWS e na Azure, e de rodar
Kubernetes localmente com `kind` (repositório `docker-kubernetes-lab`),
resolvi fechar a trinca de nuvens indo pro Google Cloud — e dessa vez com
Kubernetes gerenciado de verdade (GKE), não só container local.

No meu lab local eu sempre esbarrava na mesma limitação: um `Service` do
tipo `LoadBalancer` nunca sai do estado `<pending>`, porque não existe um
balanceador de carga de verdade rodando na minha máquina. Este projeto é o
"final feliz" dessa história: o mesmo manifesto Kubernetes que eu já tinha
testado localmente, agora rodando num cluster GKE real, com um IP público
de verdade saindo do ar em minutos.

## O que este Terraform provisiona

- Uma VPC dedicada (`vpc-gke`) e uma subnet própria, em vez de usar a rede
  padrão do projeto.
- Um cluster GKE **zonal** (`gke-aula-infra`).
- Um node pool separado do cluster, com service account própria e escopos
  OAuth explícitos (`logging.write`, `monitoring`, `cloud-platform`).
- Nós preemptíveis (`preemptible = true`), pra manter o custo o mais baixo
  possível.

## Um obstáculo real (e como contornei)

Quando fui ativar o faturamento na minha conta pessoal do Google Cloud pra
rodar isso, esbarrei em algo que não esperava: mesmo pra usar o crédito de
teste gratuito, o Google exige uma autorização de pelo menos R$ 200 no
cartão. Não é uma cobrança definitiva — é liberada depois —, mas ainda
assim é uma barreira de entrada real pra quem está estudando e não tem
essa folga disponível no cartão no momento.

Em vez de travar o projeto por causa disso, usei o **Google Cloud Skills
Boost** (o laboratório oficial "Google Kubernetes Engine: Qwik Start"), que
fornece um projeto GCP temporário já provisionado, sem pedir cartão nem
conta pessoal. Pra não pagar nada nem por isso, me inscrevi no programa
gratuito **Google Cloud Innovators** (cloud.google.com/innovators), que dá
35 créditos de aprendizado por mês — suficiente pra rodar este lab.

A limitação é que a sessão do lab dura só 45 minutos, então todo o
Terraform e os manifestos ficaram prontos de antemão, pra eu só copiar,
colar e rodar dentro da janela de tempo.

## Como eu reproduzo isso

### 0. Garantir crédito gratuito pro lab

1. Entro em **cloud.google.com/innovators** e me cadastro no programa
   (gratuito, sem cartão).
2. Isso libera 35 créditos de aprendizado por mês.
3. Procuro o lab **"Google Kubernetes Engine: Qwik Start"** no catálogo em
   skills.google.

### 1. Abrir o lab

1. Clico em **Start Lab** — é aqui que o cronômetro de 45 min começa.
2. Uso as credenciais temporárias que aparecem na tela (não a minha conta
   Google pessoal).
3. Clico em **Open Google Cloud console** e abro o **Cloud Shell** (ícone
   de terminal no topo da página).

### 2. Subir os arquivos deste projeto pro Cloud Shell

```bash
mkdir -p ~/gke-aula/k8s
cd ~/gke-aula
# colo o conteúdo de main.tf aqui, e o de k8s/app.yaml na pasta k8s/
```

### 3. Conferir a zona que o lab me deu

```bash
gcloud config get-value project
gcloud config get-value compute/zone
```

Se a zona não for `us-central1-a`, ajusto a variável `zone` (e a `region`
correspondente) no topo do `main.tf` antes de aplicar.

### 4. Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Leva de 3 a 6 minutos pra criar VPC, subnet, cluster zonal e node pool.

### 5. Conectar o kubectl ao cluster

Esse é o passo que na aula ficou implícito e eu precisei descobrir sozinho:
o Terraform cria o cluster, mas o `kubectl` só enxerga um cluster remoto
depois que eu busco as credenciais dele explicitamente.

```bash
gcloud container clusters get-credentials gke-aula-infra --zone us-central1-a
kubectl config get-contexts
kubectl get nodes
```

### 6. Aplicar a aplicação e ver o EXTERNAL-IP sair do pending

```bash
kubectl apply -f k8s/app.yaml
kubectl get service aula-nginx-lb --watch
```

Assim que o `EXTERNAL-IP` deixa de ser `<pending>` e vira um IP público, eu
abro `http://<EXTERNAL-IP>` no navegador pra confirmar que o nginx está
respondendo.

### 7. Evidências que guardei (prints, em ordem)

1. `terraform apply` concluído, com os recursos criados.
2. Console do GCP → Kubernetes Engine → Clusters, mostrando `gke-aula-infra`
   saudável.
3. `kubectl get nodes` com os nós em `Ready`.
4. `kubectl get service aula-nginx-lb` com `EXTERNAL-IP` público — a
   imagem-chave, o contraste direto com o `<pending>` eterno do meu lab
   local com `kind`.
5. O navegador abrindo `http://<EXTERNAL-IP>` com a página do nginx.

### 8. Destruir tudo antes do tempo acabar

```bash
kubectl delete -f k8s/app.yaml
terraform destroy -auto-approve
```

O projeto do lab seria destruído automaticamente pelo Google no fim da
sessão de qualquer forma, mas rodo o destroy mesmo assim — mesma disciplina
que já uso no meu lab de Azure, e não fico dependendo do timing exato do
Google.

## Decisões que tomei em relação ao material original da aula

- Troquei `location` de **região** (`us-east1`) para **zona**
  (`us-central1-a`): um cluster regional replica em 3 zonas (3 nós) e não
  entra no always-free tier numa conta paga; zonal cria mais rápido — e é
  o que eu usaria também se algum dia rodar isso na minha conta pessoal
  de verdade, pra ficar dentro do free tier.
- Troquei `machine_type` de `n4-standard-2` para `e2-medium`: disponível
  sem pedir cota extra num projeto temporário de lab.
- Tirei o `project` fixo do `provider "google"`: no Cloud Shell do lab ele
  é detectado automaticamente a partir do projeto temporário.
- O resto da estrutura (VPC dedicada, subnet, service account, node pool
  separado com `oauth_scopes`, nós preemptíveis) segue fiel ao que vi na
  aula.

## Stack

Terraform · Google Kubernetes Engine (GKE) · Google Cloud Skills Boost ·
kubectl · nginx
