#!/usr/bin/perl -w

#
# uefiTableExtract.pl (version 1.0) is a Perl script to extract DSDT and SSDT tables from UEFI-Bios.
#
#
# Version 1.0 - Copyright (c) 2013-2014 by uglyJoe
#               based on:
#               acpiTableExtract.pl v.1.2 - Copyright (c) 2013-2014 by Pike R. Alpha
#
#
# UEFIExtract is called to extract the binary files from the bios file.
#
# The binary files (.aml) will be saved in the AML sub-directory of the current bios directory.
# The IASL compiler/decompiler is called to decompile the files after the AML files are saved.
# Decompiled files will be stored in the DSL directory of the current working directory.
# If this fails with: 'Namespace lookup failure, AE_ALREADY_EXISTS', look at the output for
# the last table which makes the trouble and try something like this in Terminal:
# cd AML
# mv SSDT-trouble.aml SSDT-trouble.bin && iasl -d SSDT-trouble.bin
# iasl -da DSDT.aml SSDT*.aml
#
#
# Use MaciASL to fix/change/patch the dsl file(s).
# Use IASL (or MaciASL) to compile the modified file(s) to check for errors and warnings.
#
# Use Dsdt2Bios to compress DSDT.aml into AmiBoardInfo.bin (original is saved in the AML sub-directory).
# Use UEFITool to put AmiBoardInfo.bin and SSDT-*.aml back into bios.
#
# Note: The extracted tables are not initialized by the BIOS when we extract them, and thus 
#       they <em>cannot</em> be used as ordinary DSDT and/or SSDT to boot OS X, or any other OS.
#       The reason for this is that certain variables (memory addresses) are not filled in.
#
#
# Usage: ./uefiTableExtract.pl /path/to/bios.rom
#
# Updates:
#			- v1.0  Renamed script from acpiTableExtract.pl to uefiTableExtract.pl
#			-       Changed script to work with UEFIExtract.
#			-       ...
#

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Find;
use File::Copy 'move';
use File::Which;


#
# Defaults
#
my $pwd = cwd();
my $amlDir = "$pwd/AML";
my $dslDir = "$pwd/DSL";
my $enable_extract = 0;
my $enable_decompile = 0;


#
# Tools
#
my $IASL = which( "iasl" );
if (! -x $IASL)
{
    $IASL = "./iasl";
    if (! -x $IASL)
    {
        print "ERROR - iasl not found\n";
        $enable_decompile = 0;
    }
}

my $UEFIExtract = which( "UEFIExtract" );
if (! -x $UEFIExtract)
{
    $UEFIExtract = "./UEFIExtract";
    if (! -x $UEFIExtract)
    {
        print "ERROR - UEFIExtract not found\n";
        $enable_extract = 0;
    }
}


#
# UEFIExtract: Extract BIN files from bios
#
sub extract()
{
    my ($in) = @_;
    if ($enable_extract == 1)
    {
        printf("\nExtracting files to: %s.dump \n", $in);
        `$UEFIExtract "$in"`
    }
}

#
# IASL: Disassemble AML files
#
sub aml2dsl()
{
    our ($in, $out) = @_;
    if (($enable_decompile == 1) && (-d $in))
    {
        if (! -d $out)
        {
            `mkdir "$out"`
        }
        
        chdir($in);
        printf("\nDecompiling (iasl) Acpi tables to: %s \n\n", $out);
        move("SSDT-IdeTable.aml", "SSDT-IdeTable.bin") && `$IASL -p "$out/SSDT-IdeTable.dsl" -d SSDT-IdeTable.bin`; # quick and dirty fix
        find(\&handle_file, $in);
    }

    sub handle_file
    {
        my $targetFile = $_;
        my ($ext) = $targetFile =~ /(\.[^.]+)$/;
        if ($ext && "$ext" eq ".aml")
        {
            printf("\nDisassembling %s \n", $targetFile);
            `$IASL -p "$out/$targetFile" -e DSDT.aml SSDT*.aml -d "$targetFile"`;
        }
    }
}

#
# BIN to AML
#
sub main()
{
    print "\nuefiTableExtract.pl 1.0\n";
    print "\n";
    print "\n";
    
    my $rom = "";
    our $checkedFiles = 0;
    our $skippedFiles = 0;
    our $skippedPaddingFiles = 0;
    
    # Commandline arguments
    my $numArgs = $#ARGV + 1;
    if ($numArgs eq 1)
    {
        if (-d $ARGV[0])
        {
            $pwd = $ARGV[0];
            printf("Found dir: %s \n", $pwd);
        }
        
        elsif (-f $ARGV[0])
        {
            #$rom = File::Spec->rel2abs($ARGV[0]);
            $rom = $ARGV[0];
            printf("Found file: %s \n", $rom);
            $pwd = dirname($rom);
            chdir($pwd);
            $pwd = cwd();
            $enable_extract = 1;
        }
        else
        {
            printf("File or directory not found: %s \n", $ARGV[0]);
            exit(1);
        }
    }
    else
    {
        print "Path to ROM file?\n";
        $rom = <>;
        chomp $rom;
        $rom =~ s/^\s+|\\|\s+$//g;
        
        if (-f $rom)
        {
            printf("Found file: %s \n", $rom);
            $pwd = dirname($rom);
            chdir($pwd);
            $pwd = cwd();
            $enable_extract = 1;
        }
        else
        {
            printf("File not found: %s \n", $rom);
            exit(1);
        }
    }
    
    printf("Default path: %s \n", $pwd);
    chdir($pwd);
    $amlDir = "$pwd/AML";
    $dslDir = "$pwd/DSL";
    
    my $dump = $pwd;
    if ($rom ne "")
    {
    	&extract($rom);
        $dump = "$rom.dump";
    }
    
    if (-d $dump)
    {
        print "Searching binary files ...\n";
        find(\&revo_file, $dump);
    }

    sub revo_file
    {
		my $filename = $_;
        
		$checkedFiles++;

		# The ACPI header is 36 bytes (skipping anything smaller).
		if ( ((-s $filename) > 36) && (substr($filename, 0, 7) ne "PADDING") && ($filename eq "body.bin") )
		{
			if (open(FILE, $filename))
			{
				binmode FILE;

				my $start = 0;
				my $bytesRead = 0;
				my ($data, $patched_data, $targetFile, $signature, $length, $revision, $checksum, $id, $tid, $crev, $cid);

				while (($bytesRead = read(FILE, $signature, 4)) == 4)
				{
					$start += $bytesRead;

					if (#
						# Signatures For Tables Defined By ACPI.
						#
						$signature eq "APIC" || # APIC Description Table.
						$signature eq "MADT" || # Multiple APIC Description Table.
						$signature eq "BERT" || # Boot Error Record Table.
						$signature eq "BGRT" || # Boot Graphics Resource Table.
						$signature eq "CPEP" || # Corrected Platform Error Polling Table.
						$signature eq "DSDT" || # Differentiated System Description Table.
						$signature eq "ECDT" || # Embedded Controller Boot Resources Table.
						$signature eq "EINJ" || # Error Injection Table.
						$signature eq "ERST" || # Error Record Serialization Table.
						$signature eq "FACP" || # Firmware ACPI Control Structure.
						$signature eq "FACS" || # Firmware ACPI Control Structure.
						$signature eq "FPDT" || # Firmware Performance Data Table.
						$signature eq "GTDT" || # Generic Timer Description Table.
						$signature eq "HEST" || # Hardware Error Source Table
						$signature eq "MSCT" || # Maximum System Characteristics Table.
						$signature eq "MPST" || # Memory Power StateTable.
						$signature eq "PMTT" || # Platform Memory Topology Table.
						$signature eq "PSDT" || # Persistent System Description Table.
						$signature eq "RASF" || # CPI RAS FeatureTable
						$signature eq "SBST" || # Smart Battery Table.
						$signature eq "SLIT" || # System Locality Information Table.
						$signature eq "SRAT" || # System Resource Affinity Table.
						$signature eq "SSDT" || # Secondary System Description Table.
						#
						# Signatures For Tables Reserved By ACPI.
						#
						$signature eq "BOOT" || # Simple Boot Flag Table.
						$signature eq "CSRT" || # Core System Resource Table.
						$signature eq "DBGP" || # Debug Port Table.
						$signature eq "DBG2" || # Debug Port Table 2.
						$signature eq "DMAR" || # DMA Remapping Table.
						$signature eq "ETDT" || # Event Timer Description Table (Obsolete).
						$signature eq "HPET" || # High Precision Event Timer Table.
						$signature eq "IBFT" || # SCSI Boot Firmware Table.
						$signature eq "IVRS" || # I/O Virtualization Reporting Structure.
						$signature eq "MCFG" || # PCI Express memory mapped configuration space base address Description Table.
						$signature eq "MCHI" || # Management Controller Host Interface Table.
						$signature eq "MSDM" || # Microsoft Data Management Table.
						$signature eq "SLIC" || # Microsoft Software Licensing Table Specification.
						$signature eq "SPCR" || # Serial Port Console Redirection Table.
						$signature eq "SPMI" || # Server Platform Management Interface Table.
						$signature eq "TCPA" || # Trusted Computing Platform Alliance Capabilities Table.
						$signature eq "TPM2" || # Trusted Platform Module 2 Table.
						$signature eq "UEFI" || # UEFI ACPI Data Table.
						$signature eq "WAET" || # Windows ACPI Eemulated Devices Table.
						$signature eq "WDAT" || # Watch Dog Action Table.
						$signature eq "WDRT" || # Watchdog Resource Table.
						$signature eq "WPBT" || # Windows Platform Binary Table.
						#
						# Miscellaneous ACPI Tables.
						#
						$signature eq "PCCT" )  # Platform Communications Channel Table.
					{
						read(FILE, $length, 4);
						read(FILE, $revision, 1);	# Revision (unused)
						read(FILE, $checksum, 1);	# Checksum (unused)
						read(FILE, $id, 6);			# OEMID
						read(FILE, $tid, 8);		# OEM Table ID
						read(FILE, $crev, 4);		# OEM Revision (unused)
						read(FILE, $cid, 4);		# Creator ID (unused)

						if ($cid eq "AAPL" || $cid eq "INTL" || $id eq "      ")
						{
							printf("%s found in: %s @ 0x%x ", $signature, $filename, $start);
							$length = unpack("N", reverse($length));

							if ($signature eq "FACP" && $length lt 244)
							{
								printf(" - Skipped %s (size error)\n", $signature);
							}
							else
							{
								printf("(%d bytes) ", $length);
								
								if ($id ne "      ")
								{
									printf("'%s' ", $id);
								}

								printf("'%s' ", $tid);

								if ($signature eq "SSDT")
								{
									$targetFile = sprintf("%s-%s.aml", $signature, unpack("A8", $tid));
								}
								else
								{
									$targetFile = sprintf("%s.aml", $signature);
								}

								printf("INTL %s\n", $targetFile);

								seek(FILE, ($start - 4), 0);

								if (($bytesRead = read(FILE, $data, $length)) > 0)
								{
									if (! -d $amlDir)
									{
										`mkdir "$amlDir"`
									}

									printf("Saving raw Acpi table data to: $amlDir/$targetFile\n");
									open(OUT, ">$amlDir/$targetFile") || die $!;
									binmode OUT;
									
									# Uninitialized Acpi table data requires some patching
									if ($id eq "      ")
									{
										printf("Patching Acpi table...\n");
										$patched_data = $data;
										# Injecting OEMID (Apple ) and OEM Table ID (Apple00)
										substr($patched_data, 10) = 'APPLE Apple00';
										substr($patched_data, 23) = substr($data, 23, 5);
										# Injecting Creator ID (Loki) and Creator Revision (_) or 0x5f
										substr($patched_data, 28) = 'Loki_';
										substr($patched_data, 33) = substr($data, 33);
										$data = $patched_data;
										printf("%x ", unpack("%A8", $data));
										# Fix checksum here?
									}

									print OUT $data;
									close(OUT);
                                    
									$enable_decompile = 1;
									if ($signature eq "DSDT")
									{
										`cp "$filename" "$amlDir/AmiBoardInfo.bin"`;
									}
								}
							}

							seek(FILE, $start, 0);

							print "\n";
						}

						$signature = "";
						$cid = "";
					}
				}

				close (FILE);
			}
		}
		else
		{
			$skippedFiles++;

			if (substr($filename, 0, 7) eq "PADDING")
			{
				$skippedPaddingFiles++;
			}
		}
	}

	if ($checkedFiles > 0)
	{
		printf("%3d files checked\n%3d files skipped (shorter than Acpi table header)\n%3d file skipped (padding blocks / zero data)\n", $checkedFiles, ($skippedFiles - $skippedPaddingFiles), $skippedPaddingFiles);
	}
	else
	{
		print "Error: No .bin files found!\n";
		$enable_decompile = 0;
	}
    
	&aml2dsl($amlDir, $dslDir);
}

main();
exit(0);
