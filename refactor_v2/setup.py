from setuptools import setup, find_packages

setup(
    name="vc_analysis",
    version="0.1.0",
    description="VC Network Analysis: Python Preprocessing Pipeline",
    author="Research Team",
    packages=find_packages(),
    install_requires=[
        "pandas>=1.5.0",
        "numpy>=1.23.0",
        "networkx>=3.0",
        "python-igraph>=0.10.0",
        "scipy>=1.10.0",
        "scikit-learn>=1.2.0",
        "joblib>=1.2.0",
        "openpyxl>=3.1.0",
        "pyarrow>=11.0.0",
        "fastparquet>=2023.0.0",
        "tqdm>=4.65.0",
        "uszipcode>=1.0.0",  # US zipcode data
    ],
    extras_require={
        'dev': [
            'pytest>=7.0.0',
            'pytest-cov>=4.0.0',
            'black>=23.0.0',
            'flake8>=6.0.0',
            'jupyter>=1.0.0',
            'matplotlib>=3.7.0',
            'seaborn>=0.12.0',
        ],
        'gpu': [
            'cupy>=12.0.0',  # GPU-accelerated NumPy
            'cugraph>=23.0.0',  # GPU-accelerated NetworkX
        ]
    },
    python_requires='>=3.9',
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Science/Research',
        'Topic :: Scientific/Engineering :: Information Analysis',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
    ],
)

