# Getting Started Tutorial

Welcome to our project! This tutorial will guide you through setting up your development environment and creating your first API endpoint.

## Prerequisites

Before you begin, make sure you have:

{% hint style="info" %}
**System Requirements**
- Node.js 18 or higher
- PostgreSQL 14+
- Git
- A code editor (we recommend VS Code)
{% endhint %}

## Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
```

## Step 2: Install Dependencies

```bash
npm install
```

This will install all the necessary packages and dependencies.

## Step 3: Environment Setup

Create a `.env` file in the root directory:

```env
DATABASE_URL=postgresql://username:password@localhost:5432/your_db
JWT_SECRET=your-super-secret-key
API_PORT=3000
```

{% hint style="warning" %}
**Security Note**
Never commit your `.env` file to version control. Make sure it's listed in your `.gitignore` file.
{% endhint %}

## Next Steps

- Read our [API Guidelines](api-guidelines.md)
- Check out the [Architecture Guide](architecture.md) 
- Explore the [Deployment Guide](deployment.md)
