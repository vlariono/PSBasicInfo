$script:memberDefinition = @'

    public struct FILE_BASIC_INFO
    {
        [MarshalAs(UnmanagedType.I8)]
        public Int64 CreationTime;
        [MarshalAs(UnmanagedType.I8)]
        public Int64 LastAccessTime;
        [MarshalAs(UnmanagedType.I8)]
        public Int64 LastWriteTime;
        [MarshalAs(UnmanagedType.I8)]
        public Int64 ChangeTime;
        [MarshalAs(UnmanagedType.U4)]
        public UInt32 FileAttributes;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr CreateFile(
        [MarshalAs(UnmanagedType.LPTStr)] string filename,
        [MarshalAs(UnmanagedType.U4)] UInt32 access,
        [MarshalAs(UnmanagedType.U4)] UInt32 share,
        IntPtr securityAttributes, // optional SECURITY_ATTRIBUTES struct or IntPtr.Zero
        [MarshalAs(UnmanagedType.U4)] UInt32 creationDisposition,
        [MarshalAs(UnmanagedType.U4)] UInt32 flagsAndAttributes,
        IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetFileInformationByHandleEx(
        IntPtr hFile,
        int infoClass,
        out FILE_BASIC_INFO fileInfo,
        uint dwBufferSize);

'@ 

Add-Type -MemberDefinition $script:memberDefinition -Name 'FileBasicInfo' -Namespace 'PSBasicInfo'

function Get-ItemBasicInfo 
{
    <#
    .SYNOPSIS
        This function retrieves FILE_BASIC_INFO structure from file system item.
    .DESCRIPTION
        This structure contains ChangeTime property. The property will be updated any time metadata or data is changed. LastWriteTime will be updated only if data is changed.
    .EXAMPLE
        PS C:\> Get-Item D:\Test|Get-ItemBasicInfo 
        Pipe result of Get-item to Get-ItemBasicInfo
    .EXAMPLE
        PS C:\> Get-ChildItem -Recurse D:\Test|Get-ItemBasicInfo
        Pipe result of Get-ChildItem to Get-ItemBasicInfo
    .INPUTS
        System.IO.FileSystemInfo
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param(
        # Path to file or directory
        [Parameter(Mandatory = $true,
                Position = 0, 
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({Test-Path -Path $_.FullName})]
        [System.IO.FileSystemInfo]
        $Path
    )
    
    begin 
    {
        
    }
    
    process
    {
        $currentPath = $Path.FullName
        
        try
        {
            Write-Verbose "CreateFile: Open file $currentPath"
            $fileHandle = [PSBasicInfo.FileBasicInfo]::CreateFile($currentPath,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite,
                [System.IntPtr]::Zero,
                [System.IO.FileMode]::Open,
                [System.UInt32]0x02000000,
                [System.IntPtr]::Zero)
            
            if($fileHandle -eq -1)
            {
                throw "CreateFile: Error opening file $Path"
            }
            
            # Output object
            $fileBasicInfo = New-Object -TypeName PSBasicInfo.FileBasicInfo+FILE_BASIC_INFO
            
            Write-Verbose "GetFileInformationByHandleEx: Get basic info"
            $bRetrieved = [PSBasicInfo.FileBasicInfo]::GetFileInformationByHandleEx($fileHandle,0,
                [ref]$fileBasicInfo,
                [System.Runtime.InteropServices.Marshal]::SizeOf($fileBasicInfo))
            
            if(!$bRetrieved)
            {
                throw "GetFileInformationByHandleEx: Error retrieving item information"
            }
            
            # Return result
            [PSCustomObject]@{
                Item = $Path
                CreationTime = [System.DateTime]::FromFileTime($fileBasicInfo.CreationTime)
                LastAccessTime = [System.DateTime]::FromFileTime($fileBasicInfo.LastAccessTime)
                LastWriteTime  = [System.DateTime]::FromFileTime($fileBasicInfo.LastWriteTime)
                ChangeTime     = [System.DateTime]::FromFileTime($fileBasicInfo.ChangeTime)
                FileAttributes = $fileBasicInfo.FileAttributes
            }
        }
        catch 
        {
            throw $_
        }
        finally
        {
            Write-Verbose "CloseHandle: Close file $currentPath"
            $bClosed = [PSBasicInfo.FileBasicInfo]::CloseHandle($fileHandle)
            
            if(!$bClosed)
            {
                Write-Warning "CloseHandle: Error closing handle $fileHandle of $Path"
            }
        }
    }
}