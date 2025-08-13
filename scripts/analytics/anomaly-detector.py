#!/usr/bin/env python3
"""
Phase 6.2: Anomaly Detection Models for Claude Agent Telemetry
ML-based behavioral fingerprinting and anomaly detection.
"""

import json
import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
import argparse
import logging
import warnings
from typing import Dict, List, Tuple, Optional

# ML imports
from sklearn.ensemble import IsolationForest
from sklearn.neighbors import LocalOutlierFactor
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.decomposition import PCA
from sklearn.cluster import DBSCAN
from sklearn.metrics import silhouette_score
import joblib

# Suppress sklearn warnings
warnings.filterwarnings('ignore', category=UserWarning)

class BehavioralAnomalyDetector:
    """ML-based anomaly detection for Claude Agent behavioral patterns"""
    
    def __init__(self, data_dir: str = None, model_dir: str = None):
        self.data_dir = data_dir or "/home/jeff/claude-code/agent-telemetry/data"
        self.model_dir = model_dir or f"{self.data_dir}/analytics/models"
        self.features_dir = f"{self.data_dir}/analytics/features"
        
        # Ensure directories exist
        Path(self.model_dir).mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Model configurations
        self.models = {}
        self.scalers = {}
        self.feature_columns = []
        
        # Anomaly detection parameters
        self.isolation_forest_params = {
            'contamination': 0.1,  # Expect 10% anomalies
            'random_state': 42,
            'n_estimators': 200
        }
        
        self.lof_params = {
            'n_neighbors': 20,
            'contamination': 0.1,
            'novelty': True  # For detecting new anomalies
        }
        
        self.dbscan_params = {
            'eps': 0.5,
            'min_samples': 5
        }
    
    def load_features(self, filename: str = None) -> pd.DataFrame:
        """Load processed features from data processor"""
        if filename is None:
            filename = f"{self.features_dir}/latest_features.csv"
        
        if not os.path.exists(filename):
            self.logger.error(f"Features file not found: {filename}")
            return pd.DataFrame()
        
        try:
            df = pd.read_csv(filename)
            self.logger.info(f"Loaded {len(df)} sessions from {filename}")
            return df
        except Exception as e:
            self.logger.error(f"Failed to load features: {e}")
            return pd.DataFrame()
    
    def prepare_features(self, df: pd.DataFrame) -> Tuple[np.ndarray, List[str]]:
        """Prepare features for ML models"""
        if df.empty:
            return np.array([]), []
        
        # Select numeric features for anomaly detection
        numeric_features = [
            'duration_minutes',
            'total_operations',
            'file_operations',
            'bash_commands',
            'search_operations',
            'ai_operations',
            'scope_violations',
            'operation_rate',
            'tool_diversity',
            'error_rate',
            'superclaude_usage',
            'unique_tools_count',
            'workflow_types_count',
            'personas_count',
            'reasoning_levels_count',
            'unique_files_count'
        ]
        
        # Add temporal features if available
        temporal_features = [
            'operations_mean',
            'operations_std',
            'operations_max',
            'operations_min',
            'peak_hour_frequency'
        ]
        
        for feature in temporal_features:
            if feature in df.columns:
                numeric_features.append(feature)
        
        # Add sequence features if available
        sequence_features = [
            'sequence_length',
            'unique_transitions',
            'transition_entropy',
            'read_write_cycles',
            'bash_after_edit',
            'search_then_read',
            'repetitive_patterns'
        ]
        
        for feature in sequence_features:
            if feature in df.columns:
                numeric_features.append(feature)
        
        # Filter features that exist in the dataframe
        available_features = [f for f in numeric_features if f in df.columns]
        
        if not available_features:
            self.logger.error("No numeric features found for anomaly detection")
            return np.array([]), []
        
        # Handle missing values
        feature_df = df[available_features].fillna(0)
        
        # Remove sessions with all zero values (likely incomplete data)
        non_zero_mask = (feature_df != 0).any(axis=1)
        feature_df = feature_df[non_zero_mask]
        
        self.logger.info(f"Prepared {len(feature_df)} sessions with {len(available_features)} features")
        self.feature_columns = available_features
        
        return feature_df.values, available_features
    
    def train_isolation_forest(self, X: np.ndarray) -> Dict:
        """Train Isolation Forest for global anomaly detection"""
        self.logger.info("Training Isolation Forest model...")
        
        # Scale features
        scaler = RobustScaler()  # More robust to outliers
        X_scaled = scaler.fit_transform(X)
        
        # Train model
        model = IsolationForest(**self.isolation_forest_params)
        model.fit(X_scaled)
        
        # Predict anomalies on training data
        anomaly_scores = model.decision_function(X_scaled)
        predictions = model.predict(X_scaled)
        
        # Calculate metrics
        n_anomalies = np.sum(predictions == -1)
        anomaly_rate = n_anomalies / len(predictions)
        
        results = {
            'model': model,
            'scaler': scaler,
            'anomaly_scores': anomaly_scores,
            'predictions': predictions,
            'n_anomalies': n_anomalies,
            'anomaly_rate': anomaly_rate,
            'score_threshold': np.percentile(anomaly_scores, 10)  # Bottom 10% as anomalies
        }
        
        self.models['isolation_forest'] = model
        self.scalers['isolation_forest'] = scaler
        
        self.logger.info(f"Isolation Forest: {n_anomalies}/{len(predictions)} anomalies ({anomaly_rate:.2%})")
        return results
    
    def train_local_outlier_factor(self, X: np.ndarray) -> Dict:
        """Train Local Outlier Factor for local density-based anomaly detection"""
        self.logger.info("Training Local Outlier Factor model...")
        
        # Scale features
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # Train model
        model = LocalOutlierFactor(**self.lof_params)
        model.fit(X_scaled)
        
        # Get outlier scores
        outlier_scores = model.negative_outlier_factor_
        
        # For novelty detection, we need to use decision_function
        predictions = model.predict(X_scaled)
        
        # Calculate metrics
        n_anomalies = np.sum(predictions == -1)
        anomaly_rate = n_anomalies / len(predictions)
        
        results = {
            'model': model,
            'scaler': scaler,
            'outlier_scores': outlier_scores,
            'predictions': predictions,
            'n_anomalies': n_anomalies,
            'anomaly_rate': anomaly_rate,
            'score_threshold': np.percentile(outlier_scores, 10)
        }
        
        self.models['lof'] = model
        self.scalers['lof'] = scaler
        
        self.logger.info(f"LOF: {n_anomalies}/{len(predictions)} anomalies ({anomaly_rate:.2%})")
        return results
    
    def train_clustering_based_detection(self, X: np.ndarray) -> Dict:
        """Train DBSCAN clustering for behavioral pattern detection"""
        self.logger.info("Training DBSCAN clustering model...")
        
        # Scale features
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # Apply PCA for dimensionality reduction if needed
        pca = None
        if X_scaled.shape[1] > 10:
            pca = PCA(n_components=10, random_state=42)
            X_scaled = pca.fit_transform(X_scaled)
        
        # Train DBSCAN
        model = DBSCAN(**self.dbscan_params)
        cluster_labels = model.fit_predict(X_scaled)
        
        # Identify anomalies (points labeled as -1)
        anomalies = cluster_labels == -1
        n_anomalies = np.sum(anomalies)
        anomaly_rate = n_anomalies / len(cluster_labels)
        
        # Calculate cluster statistics
        n_clusters = len(set(cluster_labels)) - (1 if -1 in cluster_labels else 0)
        
        # Calculate silhouette score if we have clusters
        silhouette = 0
        if n_clusters > 1 and not np.all(anomalies):
            try:
                silhouette = silhouette_score(X_scaled[~anomalies], cluster_labels[~anomalies])
            except:
                pass
        
        results = {
            'model': model,
            'scaler': scaler,
            'pca': pca,
            'cluster_labels': cluster_labels,
            'anomalies': anomalies,
            'n_anomalies': n_anomalies,
            'anomaly_rate': anomaly_rate,
            'n_clusters': n_clusters,
            'silhouette_score': silhouette
        }
        
        self.models['dbscan'] = model
        self.scalers['dbscan'] = scaler
        if pca:
            self.models['dbscan_pca'] = pca
        
        self.logger.info(f"DBSCAN: {n_clusters} clusters, {n_anomalies}/{len(cluster_labels)} anomalies ({anomaly_rate:.2%})")
        return results
    
    def create_behavioral_profiles(self, df: pd.DataFrame, X: np.ndarray, results: Dict) -> pd.DataFrame:
        """Create behavioral profiles with anomaly scores and risk assessment"""
        profiles = df.copy()
        
        # Add anomaly scores from different models
        if 'isolation_forest' in results:
            if_results = results['isolation_forest']
            profiles['if_anomaly_score'] = if_results['anomaly_scores']
            profiles['if_is_anomaly'] = if_results['predictions'] == -1
        
        if 'lof' in results:
            lof_results = results['lof']
            profiles['lof_outlier_score'] = lof_results['outlier_scores']
            profiles['lof_is_anomaly'] = lof_results['predictions'] == -1
        
        if 'dbscan' in results:
            dbscan_results = results['dbscan']
            profiles['cluster_label'] = dbscan_results['cluster_labels']
            profiles['cluster_is_anomaly'] = dbscan_results['anomalies']
        
        # Calculate composite risk score
        risk_factors = []
        
        if 'if_anomaly_score' in profiles.columns:
            # Normalize IF scores to 0-1 range
            if_scores = profiles['if_anomaly_score'].values
            if_normalized = (if_scores - if_scores.min()) / (if_scores.max() - if_scores.min() + 1e-10)
            risk_factors.append(1 - if_normalized)  # Lower scores = higher risk
        
        if 'lof_outlier_score' in profiles.columns:
            # Normalize LOF scores to 0-1 range
            lof_scores = profiles['lof_outlier_score'].values
            lof_normalized = (lof_scores - lof_scores.min()) / (lof_scores.max() - lof_scores.min() + 1e-10)
            risk_factors.append(1 - lof_normalized)  # Lower scores = higher risk
        
        # Add behavioral risk factors
        if 'scope_violations' in profiles.columns:
            violations = profiles['scope_violations'].values
            if violations.max() > 0:
                risk_factors.append(violations / violations.max())
        
        if 'error_rate' in profiles.columns:
            error_rates = profiles['error_rate'].values
            if error_rates.max() > 0:
                risk_factors.append(error_rates / error_rates.max())
        
        # Calculate composite risk score
        if risk_factors:
            profiles['composite_risk_score'] = np.mean(risk_factors, axis=0)
        else:
            profiles['composite_risk_score'] = 0
        
        # Risk categories
        profiles['risk_category'] = pd.cut(
            profiles['composite_risk_score'],
            bins=[0, 0.3, 0.6, 0.8, 1.0],
            labels=['Low', 'Medium', 'High', 'Critical']
        )
        
        # Behavioral fingerprint (top features for each session)
        feature_importance = self.calculate_feature_importance(X)
        profiles['behavioral_fingerprint'] = profiles.apply(
            lambda row: self.generate_fingerprint(row, feature_importance), axis=1
        )
        
        return profiles
    
    def calculate_feature_importance(self, X: np.ndarray) -> Dict[str, float]:
        """Calculate feature importance using variance and correlation analysis"""
        if len(self.feature_columns) != X.shape[1]:
            return {}
        
        # Feature variance (higher variance = more discriminative)
        variances = np.var(X, axis=0)
        
        # Normalize to 0-1 range
        max_var = np.max(variances)
        if max_var > 0:
            normalized_vars = variances / max_var
        else:
            normalized_vars = np.zeros_like(variances)
        
        importance = {}
        for i, feature in enumerate(self.feature_columns):
            importance[feature] = normalized_vars[i]
        
        return importance
    
    def generate_fingerprint(self, session_row: pd.Series, feature_importance: Dict[str, float]) -> str:
        """Generate behavioral fingerprint for a session"""
        if not feature_importance:
            return "unknown"
        
        # Get top 3 most important features for this session
        feature_values = []
        for feature, importance in sorted(feature_importance.items(), key=lambda x: x[1], reverse=True)[:3]:
            if feature in session_row:
                value = session_row[feature]
                if pd.notna(value) and value != 0:
                    feature_values.append(f"{feature}:{value:.1f}")
        
        return ",".join(feature_values[:3]) if feature_values else "minimal_activity"
    
    def save_models(self, timestamp: str = None):
        """Save trained models and scalers"""
        if timestamp is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save models
        for model_name, model in self.models.items():
            filename = f"{self.model_dir}/{model_name}_{timestamp}.joblib"
            joblib.dump(model, filename)
            # Also save as latest
            latest_filename = f"{self.model_dir}/{model_name}_latest.joblib"
            joblib.dump(model, latest_filename)
        
        # Save scalers
        for scaler_name, scaler in self.scalers.items():
            filename = f"{self.model_dir}/{scaler_name}_scaler_{timestamp}.joblib"
            joblib.dump(scaler, filename)
            # Also save as latest
            latest_filename = f"{self.model_dir}/{scaler_name}_scaler_latest.joblib"
            joblib.dump(scaler, latest_filename)
        
        # Save feature columns
        feature_config = {
            'feature_columns': self.feature_columns,
            'timestamp': timestamp,
            'model_params': {
                'isolation_forest': self.isolation_forest_params,
                'lof': self.lof_params,
                'dbscan': self.dbscan_params
            }
        }
        
        with open(f"{self.model_dir}/model_config_{timestamp}.json", 'w') as f:
            json.dump(feature_config, f, indent=2)
        
        with open(f"{self.model_dir}/model_config_latest.json", 'w') as f:
            json.dump(feature_config, f, indent=2)
        
        self.logger.info(f"Saved models and configuration to {self.model_dir}")
    
    def load_models(self, timestamp: str = "latest"):
        """Load trained models and scalers"""
        try:
            # Load feature configuration
            config_file = f"{self.model_dir}/model_config_{timestamp}.json"
            with open(config_file, 'r') as f:
                config = json.load(f)
            
            self.feature_columns = config['feature_columns']
            
            # Load models
            model_files = {
                'isolation_forest': f"{self.model_dir}/isolation_forest_{timestamp}.joblib",
                'lof': f"{self.model_dir}/lof_{timestamp}.joblib",
                'dbscan': f"{self.model_dir}/dbscan_{timestamp}.joblib"
            }
            
            for model_name, filename in model_files.items():
                if os.path.exists(filename):
                    self.models[model_name] = joblib.load(filename)
            
            # Load scalers
            scaler_files = {
                'isolation_forest': f"{self.model_dir}/isolation_forest_scaler_{timestamp}.joblib",
                'lof': f"{self.model_dir}/lof_scaler_{timestamp}.joblib",
                'dbscan': f"{self.model_dir}/dbscan_scaler_{timestamp}.joblib"
            }
            
            for scaler_name, filename in scaler_files.items():
                if os.path.exists(filename):
                    self.scalers[scaler_name] = joblib.load(filename)
            
            # Load PCA if exists
            pca_file = f"{self.model_dir}/dbscan_pca_{timestamp}.joblib"
            if os.path.exists(pca_file):
                self.models['dbscan_pca'] = joblib.load(pca_file)
            
            self.logger.info(f"Loaded models from {timestamp}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to load models: {e}")
            return False
    
    def predict_anomalies(self, X: np.ndarray) -> Dict:
        """Predict anomalies on new data using trained models"""
        if not self.models or not self.scalers:
            self.logger.error("No trained models available. Train models first.")
            return {}
        
        predictions = {}
        
        # Isolation Forest predictions
        if 'isolation_forest' in self.models and 'isolation_forest' in self.scalers:
            X_scaled = self.scalers['isolation_forest'].transform(X)
            scores = self.models['isolation_forest'].decision_function(X_scaled)
            preds = self.models['isolation_forest'].predict(X_scaled)
            predictions['isolation_forest'] = {
                'scores': scores,
                'predictions': preds,
                'anomalies': preds == -1
            }
        
        # LOF predictions
        if 'lof' in self.models and 'lof' in self.scalers:
            X_scaled = self.scalers['lof'].transform(X)
            scores = self.models['lof'].decision_function(X_scaled)
            preds = self.models['lof'].predict(X_scaled)
            predictions['lof'] = {
                'scores': scores,
                'predictions': preds,
                'anomalies': preds == -1
            }
        
        return predictions
    
    def train_all_models(self, features_file: str = None) -> Dict:
        """Train all anomaly detection models on telemetry data"""
        self.logger.info("Starting Phase 6.2 anomaly detection training...")
        
        # Load features
        df = self.load_features(features_file)
        if df.empty:
            self.logger.error("No features available for training")
            return {}
        
        # Prepare features
        X, feature_names = self.prepare_features(df)
        if len(X) == 0:
            self.logger.error("No valid features for training")
            return {}
        
        self.logger.info(f"Training on {len(X)} sessions with {len(feature_names)} features")
        
        # Train models
        results = {}
        
        try:
            results['isolation_forest'] = self.train_isolation_forest(X)
        except Exception as e:
            self.logger.error(f"Isolation Forest training failed: {e}")
        
        try:
            results['lof'] = self.train_local_outlier_factor(X)
        except Exception as e:
            self.logger.error(f"LOF training failed: {e}")
        
        try:
            results['dbscan'] = self.train_clustering_based_detection(X)
        except Exception as e:
            self.logger.error(f"DBSCAN training failed: {e}")
        
        if not results:
            self.logger.error("All model training failed")
            return {}
        
        # Create behavioral profiles
        profiles = self.create_behavioral_profiles(df, X, results)
        
        # Save profiles
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        profiles_file = f"{self.data_dir}/analytics/behavioral_profiles_{timestamp}.csv"
        profiles.to_csv(profiles_file, index=False)
        profiles.to_csv(f"{self.data_dir}/analytics/latest_behavioral_profiles.csv", index=False)
        
        # Save models
        self.save_models(timestamp)
        
        # Generate summary report
        summary = self.generate_summary_report(results, profiles)
        
        with open(f"{self.data_dir}/analytics/anomaly_detection_summary_{timestamp}.json", 'w') as f:
            json.dump(summary, f, indent=2, default=str)
        
        self.logger.info("Anomaly detection training completed successfully!")
        self.logger.info(f"Results: {summary['total_sessions']} sessions analyzed, "
                        f"{summary['total_anomalies']} anomalies detected")
        
        return results
    
    def generate_summary_report(self, results: Dict, profiles: pd.DataFrame) -> Dict:
        """Generate comprehensive summary of anomaly detection results"""
        summary = {
            'timestamp': datetime.now().isoformat(),
            'total_sessions': len(profiles),
            'models_trained': list(results.keys()),
            'feature_count': len(self.feature_columns),
            'features_used': self.feature_columns
        }
        
        # Model-specific results
        total_anomalies = 0
        for model_name, model_results in results.items():
            if 'n_anomalies' in model_results:
                summary[f'{model_name}_anomalies'] = model_results['n_anomalies']
                summary[f'{model_name}_anomaly_rate'] = model_results['anomaly_rate']
                total_anomalies += model_results['n_anomalies']
        
        summary['total_anomalies'] = total_anomalies
        
        # Risk distribution
        if 'risk_category' in profiles.columns:
            risk_dist = profiles['risk_category'].value_counts().to_dict()
            summary['risk_distribution'] = risk_dist
        
        # Behavioral insights
        if 'composite_risk_score' in profiles.columns:
            summary['risk_score_stats'] = {
                'mean': profiles['composite_risk_score'].mean(),
                'std': profiles['composite_risk_score'].std(),
                'max': profiles['composite_risk_score'].max(),
                'min': profiles['composite_risk_score'].min()
            }
        
        # Top anomalous sessions
        if 'composite_risk_score' in profiles.columns:
            top_anomalies = profiles.nlargest(5, 'composite_risk_score')[
                ['session_id', 'composite_risk_score', 'risk_category', 'behavioral_fingerprint']
            ].to_dict('records')
            summary['top_anomalous_sessions'] = top_anomalies
        
        return summary

def main():
    parser = argparse.ArgumentParser(description='Train anomaly detection models on Claude Agent Telemetry')
    parser.add_argument('--data-dir', default=None, help='Data directory path')
    parser.add_argument('--features-file', default=None, help='Specific features file to use')
    parser.add_argument('--load-models', default=None, help='Load existing models (timestamp or "latest")')
    
    args = parser.parse_args()
    
    detector = BehavioralAnomalyDetector(data_dir=args.data_dir)
    
    if args.load_models:
        success = detector.load_models(args.load_models)
        if success:
            print(f"✅ Models loaded from {args.load_models}")
        else:
            print(f"❌ Failed to load models from {args.load_models}")
            sys.exit(1)
    else:
        results = detector.train_all_models(args.features_file)
        
        if results:
            print(f"\n✅ Successfully trained anomaly detection models!")
            print(f"🎯 Models: {', '.join(results.keys())}")
            print(f"📊 Check: {detector.data_dir}/analytics/latest_behavioral_profiles.csv")
        else:
            print("❌ Model training failed. Check logs for details.")
            sys.exit(1)

if __name__ == "__main__":
    main()