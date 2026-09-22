# Docker & Kubernetes Lab

Repositório com os laboratórios práticos que fiz na disciplina de Cloud
Computing da Pós em AI Engineering (Impacta), cobrindo containerização,
orquestração local e Kubernetes gerenciado na nuvem. A ideia é mostrar a
evolução: primeiro container isolado, depois orquestração multi-serviço,
depois Kubernetes local, e por fim o mesmo tipo de manifesto rodando num
cluster gerenciado de verdade (GKE), provisionado via Terraform.

## Estrutura do repositório

```
docker-kubernetes-lab/
├── docker-lab/          # Container customizado + orquestração local
├── k8s-gcp-lab/         # Manifestos Kubernetes (Pod, Deployment, Service)
└── terraform-gke-lab/   # Cluster GKE provisionado via Terraform
```

### [`docker-lab/`](./docker-lab)

Uma imagem Docker customizada (`dockerfile` + `index.html`) orquestrada com
`docker-compose.yaml`. Primeiro contato com containerização: build de
imagem própria e subida de serviço via compose.

### [`k8s-gcp-lab/`](./k8s-gcp-lab)

Manifestos Kubernetes puros — `pod.yaml`, `deployment.yaml` e
`service.yaml` — testados localmente num cluster `kind` (via Docker
Desktop). É aqui que fica visível a diferença entre subir um `Pod` avulso e
um `Deployment` com réplicas e `Service` do tipo `LoadBalancer` na frente.
Localmente, esse `LoadBalancer` nunca sai do estado `<pending>`, porque não
existe um balanceador de carga de verdade rodando na minha máquina — o que
me levou ao próximo passo.

### [`terraform-gke-lab/`](./terraform-gke-lab)

O "final feliz" da história acima: os mesmos manifestos de
`k8s-gcp-lab`, agora aplicados num cluster **GKE (Google Kubernetes
Engine)** real, provisionado via Terraform (VPC dedicada, subnet, service
account, cluster zonal e node pool). Dessa vez o `LoadBalancer` sai do
`<pending>` e ganha um `EXTERNAL-IP` público de verdade. Esse projeto tem
seu próprio README com o passo a passo completo, incluindo como rodei tudo
isso via Google Cloud Skills Boost (sem precisar de cartão de crédito
pessoal) — detalhes em [`terraform-gke-lab/README.md`](./terraform-gke-lab/README.md).

## Stack

Docker · Docker Compose · Kubernetes (kind) · Terraform · Google Kubernetes
Engine (GKE) · Google Cloud Skills Boost

## Contexto

Este repositório também faz parte de um portfólio maior de
Infraestrutura como Código, ao lado de laboratórios equivalentes em AWS e
Azure — a ideia é ter a mesma disciplina de provisionamento (Terraform,
destruição dos recursos ao final, documentação do processo) replicada nas
três nuvens.
