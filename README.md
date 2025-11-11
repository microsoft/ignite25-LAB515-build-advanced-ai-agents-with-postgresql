<p align="center">
<img src="img/Banner-ignite-25.png" alt="decorative banner" width="1200"/>
</p>

# [Microsoft Ignite 2025](https://ignite.microsoft.com)

## 🔥LAB515: Build advanced AI Agents with PostgreSQL

[![Microsoft Azure AI Foundry Discord](https://dcbadge.limes.pink/api/server/ByRwuEEgH4)](https://discord.com/invite/ByRwuEEgH4)
[![Azure AI Foundry Developer Forum](https://img.shields.io/badge/GitHub-Azure_AI_Foundry_Developer_Forum-blue?style=for-the-badge&logo=github&color=adff2f&logoColor=fff)](https://aka.ms/foundry/forum)

### 🧠 Session Description

In this hands-on lab, you’ll build an AI-powered legal research assistant that reasons over real-world case law data using PostgreSQL and Semantic Kernel.
You’ll learn how to combine retrieval-augmented generation (RAG), vector search, and graph intelligence to develop an agentic workflow capable of generating accurate, contextual, and explainable answers — all running on Azure Database for PostgreSQL.

### 💡 Learning Outcomes

By the end of this lab, you will be able to:

- Configure Azure Database for PostgreSQL Flexible Server with AI extensions (`azure_ai`, `pgvector`, `diskann`, and `apache_age`)
- Use Semantic Kernel to build autonomous agents with database and web plugins
- Implement semantic search and reranking using vector embeddings
- Enhance reasoning quality using the GraphRAG pattern
- Deploy your AI agent and supporting infrastructure on Azure using Bicep and CLI automation

### 💻 Technologies Used

1. Azure Database for PostgreSQL Flexible Server (with AI extensions)
1. Semantic Kernel (for agent orchestration)
1. Azure OpenAI Service (embeddings + LLM completions)
1. Python (agent runtime and notebook execution)
1. Apache `AGE` (for graph storage and reasoning)
1. `DiskANN` (for fast approximate vector similarity search)
1. VS Code PostgreSQL Extension (for hands-on queries and debugging)

### 🏗️ Architecture

```mathematica
User Query → Semantic Kernel Agent → PostgreSQL (Vector + Graph + AI) → Azure OpenAI → Contextual Answer
```

- Semantic Kernel Agent: Handles reasoning, plugin invocation, and dialogue context.
- PostgreSQL: Stores case law data, embeddings, and graph relationships.
- GraphRAG: Uses Apache AGE to connect related entities and improve recall.
- Azure OpenAI: Powers embeddings and completion for semantic responses.

### 📘 Lab Structure

|Folder                |Description                                             |
|----------------------|--------------------------------------------------------|
|lab/                  |Core Jupyter notebooks and sample scripts               |
|data/                 |Sample dataset (cases.csv) for legal research queries   |
|src/                  |Source code for agents, plugins, and database connectors|
|docs/                 |Step-by-step lab manual and architecture guide          |
|img/                  |Architecture and concept diagrams                       |
|.devcontainer/        |Preconfigured environment for VS Code                   |
|infra/ (if applicable)|Deployment templates (Bicep + PowerShell scripts)       |

### 🚀 Getting Started

#### 1️⃣ Setup Environment

- Ensure you have an Azure subscription with access to Azure OpenAI.
- Install required CLI tools:

```bash
azd auth login
azd env new
azd provision
```
This will deploy the Azure resources (PostgreSQL + OpenAI) and generate a .env file containing connection details.

#### 2️⃣ Configure Database

Use the provided scripts in /lab to:
    - Initialize tables and vector indexes
    - Load the sample case law dataset
    - Enable `azure_ai`, `pgvector`, and `apache_age` extensions

#### 3️⃣ Run the Lab Notebook

Open `lab/ai-agent-lab.ipynb` in Visual Studio Code and follow the guided steps to:

- Connect to your database
- Generate embeddings
- Execute semantic and graph-based queries
- Interact with your AI Agent

### 🌐 MCP Server Integration

This lab includes a connection to the Microsoft Learn MCP Server.
It allows your AI Agent (via Semantic Kernel) to access trusted Microsoft Learn documentation in real time.

Learn more: https://github.com/MicrosoftDocs/MCP

### 📚 Resources and Next Steps

|Resource                |Link                                |Description                                    |
|------------------------|------------------------------------|-----------------------------------------------|
|Ignite 2025 Next Steps  |https://aka.ms/Ignite25-Next-Steps  |Explore all Ignite 2025 learning paths         |
|Azure AI Foundry Discord|https://aka.ms/azureaifoundrydiscord|Connect with the Azure AI Foundry team         |
|Learn at Ignite         |https://aka.ms/LearnAtIgnite        |Continue learning on Microsoft Learn           |
|GraphRAG for PostgreSQL |aka.ms/GraphRAG-PG                  |Learn how to add graph intelligence to Postgres|
|Semantic Kernel Docs    |https://aka.ms/SemanticKernel       |Build your own AI agents with SK               |

## Content Owners

<table>
<tr>
    <td align="center"><a href="https://github.com/varun-dhawan">
        <img src="https://github.com/varun-dhawan.png" width="100px;" alt="Varun Dhawan"/><br />
        <sub><b>Varun Dhawan</b></sub>
    </a><br />
        <a href="https://github.com/varun-dhawan" title="talk">📢</a> 
    </td>
    <td align="center"><a href="https://github.com/jjfrost">
        <img src="https://github.com/jjfrost.png" width="100px;" alt="Jonathon Frost"/><br />
        <sub><b>Jason Frost</b></sub>
    </a><br />
        <a href="https://github.com/jjfrost" title="talk">📢</a> 
    </td>
    <td align="center"><a href="https://github.com/JaredMSFT">
        <img src="https://github.com/JaredMSFT.png" width="100px;" alt="Jared Meade"/><br />
        <sub><b>Jared Shockley</b></sub>
    </a><br />
        <a href="https://github.com/JaredMSFT" title="talk">📢</a> 
    </td>
    <td align="center"><a href="https://github.com/gaurikasar">
        <img src="https://github.com/gaurikasar.png" width="100px;" alt="Gauri Kasar"/><br />
        <sub><b>Gauri Kasar</b></sub>
    </a><br />
        <a href="https://github.com/gaurikasar" title="talk">📢</a> 
    </td>
</tr>
</table>


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit [Contributor License Agreements](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.