# NovHyT: Spatiotemporal Fire Prediction via Hybrid CNN-Transformer

This repository contains the official PyTorch implementation of the research project on spatiotemporal fire spread prediction. The model integrates Convolutional Neural Networks (CNNs) for spatial feature extraction and a custom Spatiotemporal Transformer module for temporal dynamics modeling, operating on multi-spectral satellite imagery.

## Architecture Overview

The pipeline processes a sequence of specific day intervals using thermal and categorical satellite data:
* **Spatial Encoder:** CNN-based feature extractor for VIIRS thermal sequences and ESRI Land Use/Land Cover data.
* **Spatiotemporal Transformer:** A Vision Transformer (ViT) variant leveraging temporal attention mechanisms to model fire spread dynamics over consecutive days.
* **Temporal Attention Pooling:** Dynamically weights the temporal features to focus on the most critical days.
* **Generative Decoder:** Utilizes transposed convolutions to reconstruct the final probability map of the fire extent.
* **Masked Focal-Dice Loss:** A custom objective function designed to handle severe class imbalances inherent in wildfire datasets.

## Academic Context

This repository is part of an academic research project focusing on applied mathematics and advanced deep learning techniques (ECE452). It explores the applicability of attention mechanisms and generative architectures in earth observation tasks.

## Setup and Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/NovHyT-Fire-Prediction.git](https://github.com/yourusername/NovHyT-Fire-Prediction.git)
   cd NovHyT-Fire-Prediction
