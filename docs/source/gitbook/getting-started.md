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

## Troubleshooting

### Common Issues

#### Database Connection Issues

**Problem**: `ECONNREFUSED` error when starting the application

**Solution**: 
1. Ensure PostgreSQL is running: `brew services start postgresql` (macOS) or `sudo systemctl start postgresql` (Linux)
2. Verify your database exists: `psql -U username -d your_db`
3. Check your `DATABASE_URL` in `.env` file

#### Port Already in Use

**Problem**: `EADDRINUSE` error on startup

**Solution**:
```bash
# Find the process using port 3000
lsof -ti:3000
# Kill the process
kill -9 <PID>
```

#### Dependencies Installation Fails

**Problem**: `npm install` fails with permission errors

**Solution**:
- Use Node Version Manager (nvm) to manage Node.js versions
- Avoid using `sudo npm install`
- Clear npm cache: `npm cache clean --force`

#### Environment Variables Not Loading

**Problem**: Application can't find environment variables

**Solution**:
1. Ensure `.env` file is in the project root
2. Check file permissions: `chmod 644 .env`
3. Restart your development server

{% hint style="info" %}
**Still Having Issues?**
Check our [FAQ section](faq.md) or open an issue on our [GitHub repository](https://github.com/your-org/your-project/issues).
{% endhint %}

## Next Steps

- Read our [API Guidelines](api-guidelines.md)
- Check out the [Architecture Guide](architecture.md) 
- Explore the [Deployment Guide](deployment.md)
