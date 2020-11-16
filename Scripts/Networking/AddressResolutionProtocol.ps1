
# Code from https://social.technet.microsoft.com/Forums/lync/en-US/e949b8d6-17ad-4afc-88cd-0019a3ac9df9/powershell-alternative-to-arp-a
$source = @"
namespace Netzwerker.Network.Diagnostics
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel;
    using System.Management.Automation;
    using System.Net;
    using System.Net.NetworkInformation;
    using System.Runtime.InteropServices;

    [Serializable]
    public class ArpEntry
    {
        public IPAddress Address;
        public PhysicalAddress MAC;
        public ArpEntryType Type;
        public int IndexAdapter;
        public int PhysAddrLength;

        internal ArpHost.MIB_IPNETROW GetRawStruct()
        {
            // Create object to be returned
            ArpHost.MIB_IPNETROW temp = new ArpHost.MIB_IPNETROW();

            // Copy index
            temp.dwIndex = IndexAdapter;

            // Copy IP
            #pragma warning disable 618
            temp.dwAddr = (int)Address.Address;
            #pragma warning restore 618

            // Copy MAC
            byte[] mac = MAC.GetBytes();
            temp.mac0 = mac[0];
            temp.mac1 = mac[1];
            temp.mac2 = mac[2];
            temp.mac3 = mac[3];
            temp.mac4 = mac[4];
            temp.mac5 = mac[5];
            temp.dwPhysAddrLen = 6;

            // Get Type
            temp.dwType = Type.GetHashCode();

            // Return object
            return temp;
        }

        public void Delete()
        {
            ArpHost.DeleteIpNetEntry(GetRawStruct());
        }
    }

    public enum ArpEntryType
    {
        Other = 1,
        Invalid = 2,
        Dynamic = 3,
        Static = 4,
    }

    public static class ArpHost
    {
        #region PInvoke Stuff

        // The max number of physical addresses.
        const int MAXLEN_PHYSADDR = 8;

        // The insufficient buffer error.
        const int ERROR_INSUFFICIENT_BUFFER = 122;

        // Define the MIB_IPNETROW structure.
        [StructLayout(LayoutKind.Sequential)]
        internal struct MIB_IPNETROW
        {
            [MarshalAs(UnmanagedType.U4)]
            public int dwIndex;
            [MarshalAs(UnmanagedType.U4)]
            public int dwPhysAddrLen;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac0;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac1;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac2;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac3;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac4;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac5;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac6;
            [MarshalAs(UnmanagedType.U1)]
            public byte mac7;
            [MarshalAs(UnmanagedType.U4)]
            public int dwAddr;
            [MarshalAs(UnmanagedType.U4)]
            public int dwType;
        }

        // Declare the GetIpNetTable function.
        [DllImport("IpHlpApi.dll")]
        [return: MarshalAs(UnmanagedType.U4)]
        internal static extern int GetIpNetTable(IntPtr pIpNetTable, [MarshalAs(UnmanagedType.U4)]ref int pdwSize, bool bOrder);

        // Method that releases reserved memory
        [DllImport("IpHlpApi.dll", SetLastError = true, CharSet = CharSet.Auto)]
        internal static extern int FreeMibTable(IntPtr plpNetTable);

        // Flushes the arp table
        [DllImport("IpHlpApi.dll")]
        [return: MarshalAs(UnmanagedType.U4)]
        internal static extern int FlushIpNetTable(int dwIfIndex);

        // Creates a new arp entry
        [DllImport("IpHlpApi.dll")]
        [return: MarshalAs(UnmanagedType.U4)]
        internal static extern int CreateIpNetEntry(MIB_IPNETROW pArpEntry);

        // Deletes a new arp entry
        [DllImport("IpHlpApi.dll")]
        [return: MarshalAs(UnmanagedType.U4)]
        internal static extern int DeleteIpNetEntry(MIB_IPNETROW pArpEntry);

        #endregion PInvoke Stuff

        #region Main output methods

        public static void Clear(int AdapterIndex)
        {
            int temp = FlushIpNetTable(AdapterIndex);
            if (temp != 0) { throw new RuntimeException("An error occured while trying to flush the Arp table"); }
        }

        public static IList<ArpEntry> Get()
        {
            // The number of bytes needed.
            int bytesNeeded = 0;

            // The result from the API call.
            int result = GetIpNetTable(IntPtr.Zero, ref bytesNeeded, false);

            // Call the function, expecting an insufficient buffer.
            if (result != ERROR_INSUFFICIENT_BUFFER)
            {
                // Throw an exception.
                throw new Win32Exception(result);
            }

            // Allocate the memory, do it in a try/finally block, to ensure that it is released.
            IntPtr buffer = IntPtr.Zero;

            // Try/finally.
            try
            {
                // Allocate the memory.
                buffer = Marshal.AllocCoTaskMem(bytesNeeded);

                // Make the call again. If it did not succeed, then raise an error.
                result = GetIpNetTable(buffer, ref bytesNeeded, false);

                // If the result is not 0 (no error), then throw an exception.
                if (result != 0)
                {
                    // Throw an exception.
                    throw new Win32Exception(result);
                }

                // Now we have the buffer, we have to marshal it. We can read the first 4 bytes to get the length of the buffer.
                int entries = Marshal.ReadInt32(buffer);

                // Increment the memory pointer by the size of the int.
                IntPtr currentBuffer = new IntPtr(buffer.ToInt64() + Marshal.SizeOf(typeof(int)));

                // Allocate an array of entries.
                MIB_IPNETROW[] table = new MIB_IPNETROW[entries];

                // Cycle through the entries.
                for (int index = 0; index < entries; index++)
                {
                    // Call PtrToStructure, getting the structure information.
                    table[index] = (MIB_IPNETROW)Marshal.PtrToStructure(new IntPtr(currentBuffer.ToInt64() + (index * Marshal.SizeOf(typeof(MIB_IPNETROW)))), typeof(MIB_IPNETROW));
                }

                // Collect results in this variable
                IList<ArpEntry> Reports = new List<ArpEntry>();

                // Iterate over each result
                for (int index = 0; index < entries; index++)
                {
                    // Create new report object
                    ArpEntry temp = new ArpEntry();

                    // Get IP Address
                    MIB_IPNETROW row = table[index];
                    temp.Address = new IPAddress(BitConverter.GetBytes(row.dwAddr));

                    // Get MAC Address
                    byte[] MacBytes = new byte[] { row.mac0, row.mac1, row.mac2, row.mac3, row.mac4, row.mac5 };
                    temp.MAC = new PhysicalAddress(MacBytes);

                    // Get Address Type
                    switch (row.dwType)
                    {
                        case 1:
                            temp.Type = ArpEntryType.Other;
                            break;
                        case 2:
                            temp.Type = ArpEntryType.Invalid;
                            break;
                        case 3:
                            temp.Type = ArpEntryType.Dynamic;
                            break;
                        case 4:
                            temp.Type = ArpEntryType.Static;
                            break;
                        default:
                            temp.Type = ArpEntryType.Invalid;
                            break;
                    }

                    // Get Index Adapter
                    temp.IndexAdapter = row.dwIndex;

                    // Get Physical Adapter Length
                    temp.PhysAddrLength = row.dwPhysAddrLen;

                    // Add Result to the results
                    Reports.Add(temp);
                }

                return Reports;
            }
            finally
            {
                // Release the memory.
                FreeMibTable(buffer);
            }
        }

        public static void New(IPAddress Address, PhysicalAddress MAC, int AdapterIndex)
        {
            // Create fictional ArpEntry
            ArpEntry temp = new ArpEntry();
            temp.Address = Address;
            temp.MAC = MAC;
            temp.IndexAdapter = AdapterIndex;
            temp.PhysAddrLength = 6;
            temp.Type = ArpEntryType.Static;

            // Create entry
            int res = CreateIpNetEntry(temp.GetRawStruct());

            // Report in case of error
            if (res != 0) { throw new InvalidOperationException("Unknown Error while writing entry"); }
        }

        #endregion Main output methods
    }

    /// <summary>
    /// A Physical Address (MAC) of a Network Adapter
    /// </summary>
    [Serializable]
    public class PhysicalAddress
    {
        /// <summary>
        /// The Byte Array that stores the physical address
        /// </summary>
        private byte[] _Bytes = new byte[6];

        public string Address
        {
            get
            {
                return this.ToString();
            }
            set
            {
                SetAddress(value);
            }
        }

        public PhysicalAddress()
        {

        }

        public PhysicalAddress(byte[] Bytes)
        {
            SetBytes(Bytes);
        }

        public PhysicalAddress(string Address)
        {
            try { SetAddress(Address); }
            catch (Exception e) { throw e; }
        }

        private void SetAddress(string Address)
        {
            // Split the address into hex bytes
            string[] temp = Address.Split('-');
            if (temp.Length != 6) { throw new ArgumentException("Invalid Address!"); }

            // Convert hex bytes into byte bytes
            byte[] bytes = new byte[6];

            try
            {
                bytes[0] = Byte.Parse(temp[0], System.Globalization.NumberStyles.HexNumber);
                bytes[1] = Byte.Parse(temp[1], System.Globalization.NumberStyles.HexNumber);
                bytes[2] = Byte.Parse(temp[2], System.Globalization.NumberStyles.HexNumber);
                bytes[3] = Byte.Parse(temp[3], System.Globalization.NumberStyles.HexNumber);
                bytes[4] = Byte.Parse(temp[4], System.Globalization.NumberStyles.HexNumber);
                bytes[5] = Byte.Parse(temp[5], System.Globalization.NumberStyles.HexNumber);

                // Store the byte array
                SetBytes(bytes);
            }
            catch { throw new ArgumentException("Invalid Address!"); }
        }

        public void SetBytes(byte[] Bytes)
        {
            if (Bytes.Length < 6) { throw new System.ArgumentException("Address too short to be a Physical Address"); }
            _Bytes[0] = Bytes[0];
            _Bytes[1] = Bytes[1];
            _Bytes[2] = Bytes[2];
            _Bytes[3] = Bytes[3];
            _Bytes[4] = Bytes[4];
            _Bytes[5] = Bytes[5];
        }

        public byte[] GetBytes()
        {
            byte[] temp = new byte[6];
            _Bytes.CopyTo(temp, 0);
            return temp;
        }

        public string GetManufacturerHex()
        {
            string temp = "";
            temp += _Bytes[0].ToString("X2");
            temp += _Bytes[1].ToString("X2");
            temp += _Bytes[2].ToString("X2");
            return temp;
        }

        public override string ToString()
        {
            try
            {
                string temp = "";
                temp += _Bytes[0].ToString("X2") + "-";
                temp += _Bytes[1].ToString("X2") + "-";
                temp += _Bytes[2].ToString("X2") + "-";
                temp += _Bytes[3].ToString("X2") + "-";
                temp += _Bytes[4].ToString("X2") + "-";
                temp += _Bytes[5].ToString("X2");
                return temp;
            }
            catch
            {
                return "00-00-00-00-00-00";
            }
        }
    }
}
"@
Add-Type $source

function Get-NetArpAddress {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $DoNotResolve,

        [Parameter()]
        [switch]
        $IgnoreUnresolved
    )

    # database from https://macaddress.io/database-download
    $dbFile = Join-Path -Path $PSScriptRoot -ChildPath "macaddress.io-db.csv"
    if ((Test-Path -Path $dbFile) -and ($DoNotResolve -eq $false)) {
        $db = @{}
        Get-Content -Path $dbFile | `
        ConvertFrom-Csv | `
        ForEach-Object -Process {
            $value = $_
            $key = $value.oui.Replace(":","").ToUpperInvariant()
            $db.Add($key, $value)
        }

        $results =  [Netzwerker.Network.Diagnostics.ArpHost]::Get() | ForEach-Object -Process {
            $entry = $_
            $key = $entry.MAC.ToString().Substring(0,8).Replace("-", "").ToUpperInvariant()
            Write-Verbose -Message "Processing key $key"
            if ($db.ContainsKey($key) -and ($key -ne "000000")) {
                Write-Verbose -Message "Found key $key"
                $entry | `
                Add-Member -MemberType NoteProperty -Name "Company" -Value $db[$key].companyName -PassThru
            } else {
                $entry
            }
        }

        if ($IgnoreUnresolved) {
            return ($results | Where-Object -FilterScript {Get-Member -InputObject $_ -Name "Company" -MemberType Properties})

        } else {
            return $results
        }
    } else {
        if (-not (Test-Path -Path $dbFile)) {
            Write-Warning -Message "Could not find database in $dbFile"
        }

        return [Netzwerker.Network.Diagnostics.ArpHost]::Get()
    }
}

function Get-NetArpAddressShort {
    Get-NetArpAddress -IgnoreUnresolved | Select-Object -Property Address,Company
}