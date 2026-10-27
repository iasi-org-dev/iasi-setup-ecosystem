$DefaultMode = "normal"

$Modes = @{
    "light" = @{
        ProcessorCount = 4
        MinimumMemory   = 8GB
        StartupMemory   = 8GB
        MaximumMemory   = 16GB
    }

    "normal" = @{
        ProcessorCount = 8
        MinimumMemory   = 4GB
        StartupMemory   = 8GB
        MaximumMemory   = 16GB
    }

    "heavy" = @{
        ProcessorCount = 12
        MinimumMemory   = 4GB
        StartupMemory   = 12GB
        MaximumMemory   = 16GB
    }

    "beast" = @{
        ProcessorCount = 16
        MinimumMemory   = 4GB
        StartupMemory   = 12GB
        MaximumMemory   = 64GB
    }
}

$GPUEnabled = $true
$GPUSelector = "auto"

$GPULowMemoryMappedIoSpace = 1GB
$GPUHighMemoryMappedIoSpace = 32GB
