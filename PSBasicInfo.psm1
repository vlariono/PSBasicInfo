$script:memberDefinition =  @'

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

function Get-ItemBasicInfo 
{
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
        Add-Type -MemberDefinition $script:memberDefinition -Name File -Namespace Kernel32
    }
    
    process
    {
        $currentPath = $Path.FullName
        
        try
        {
            Write-Verbose "CreateFile: Open file $currentPath"
            $fileHandle = [Kernel32.File]::CreateFile($currentPath,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read,
                [System.IntPtr]::Zero,
                [System.IO.FileMode]::Open,
                [System.UInt32]0x02000000,
                [System.IntPtr]::Zero)
            
            if($fileHandle -eq -1)
            {
                throw "CreateFile: Error opening file $Path"
            }
            
            # Output object
            $fileBasicInfo = New-Object -TypeName Kernel32.File+FILE_BASIC_INFO
            
            Write-Verbose "GetFileInformationByHandleEx: Get basic info"
            $bRetrieved = [Kernel32.File]::GetFileInformationByHandleEx($fileHandle,0,
                [ref]$fileBasicInfo,
                [System.Runtime.InteropServices.Marshal]::SizeOf($fileBasicInfo))
            
            if(!$bRetrieved)
            {
                throw "GetFileInformationByHandleEx: Error retrieving item information"
            }
            
            # Return result
            [PSCustomObject]@{
                File = $Path
                CreationTime = $fileBasicInfo.CreationTime
                LastAccessTime = $fileBasicInfo.LastAccessTime
                LastWriteTime  = $fileBasicInfo.LastWriteTime
                ChangeTime     = $fileBasicInfo.ChangeTime
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
            $bClosed = [Kernel32.File]::CloseHandle($fileHandle)
            
            if(!$bClosed)
            {
                throw "CloseHandle: Error closing handle $fileHandle of $Path"
            }
        }
    }
}