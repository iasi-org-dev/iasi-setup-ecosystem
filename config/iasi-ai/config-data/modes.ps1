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
        MinimumMemory   = 16GB
        StartupMemory   = 16GB
        MaximumMemory   = 32GB
    }

    "heavy" = @{
        ProcessorCount = 12
        MinimumMemory   = 32GB
        StartupMemory   = 32GB
        MaximumMemory   = 64GB
    }

    "beast" = @{
        ProcessorCount = 16
        MinimumMemory   = 64GB
        StartupMemory   = 64GB
        MaximumMemory   = 128GB
    }
}

$GPUEnabled = $true
$GPUSelector = "auto"

$GPULowMemoryMappedIoSpace = 1GB
$GPUHighMemoryMappedIoSpace = 32GB
