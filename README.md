# MTTCoHack-Arc

## Setup instructions HVHOST environment

1. Deploy Arc lab to Azure: 
    
    [![Deploy Arc lab to Azure](https://raw.githubusercontent.com/jkulbe-msft/MTTCoHack-Arc-coach/main/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjkulbe-msft%2FMTTCoHack-Arc-coach%2Fmain%2Fazuredeploy.json)
   
   This will set up a Hyper-V host **HVHOST** with the following VMs:
   - **DC1**: Domain Controller running Windows Server 2022 without GUI
   - **SRV1**: Windows Server 2022 with SQL Server 2022, joined to the domain corp.contoso.com
   - **LIN1**: Ubuntu Linux 24.04, standalone 

    DC1 and SRV1 are joined to the domain corp.contoso.com. The domain admin account is `corp\administrator` with the password `Somepass1`.

2. Sign in to HVHOST using RDP, open the Hyper-V console, connect to LIN1 and finish the setup by accepting the default settings. Create a user account and password and note it down.

3. Share the login details for HVHOST, DC1, SRV1 and LIN1 with the attendees.

## Setup instructions Azure environment

1. Download files from the Setup folder.

2. Connect to Azure with a **Global Admin** and an **Owner** account.

3. Start Azure CloudShell

4. Upload files downloaded from Setup folder to CloudShell. 

5. If you have many subscriptions, set the subscription where you are going to deploy the environment. For this, you can use the cmd "AZ-SetContext".
    
    ```powershell
    Set-AzContext -SubscriptionId "79c2a240-1a7f-482f-a315-xxxxxxxxx"
    ```

6. Run the script deploy.ps1 by specifying the region where you want to deploy the environment.
     
     ```powershell
    .\MTTCoHackArc_AzureSetup.ps1 -region 'northeurope'
    ```
  
   >**Note**: You have to authenticate with an owner account to Microsoft Graph by following the instructions displayed on the console. Don't walk away from the console until the deployment is done.
   >![archi](./images/graph-auth.png)

   >**Note**: If you got an error about Microsoft Graph, you may need to delete the application "Microsoft Graph PowerShell" in the menu "enterprise app"
   >![archi](./images/powershellapp.png)

7. Once the deployment is done, store credentials information to share them with attendees
    

## Clean up

1. Start **Windows PowerShell** as an **Administrator** on your local Hyper-V host.

2. Run the script MTTCoHackArc_HyperVRemove.ps1 from the setup folder
    ```powershell 
    .\MTTCoHackArc_HyperVRemove.ps1
    ```

3. Start Cloudshell

4. Run the script remove.ps1 in the Setup folder
    ```powershell
      .\MTTCoHackArc_AzureRemove.ps1
    ```