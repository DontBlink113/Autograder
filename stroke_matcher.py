"""
Complete Stroke Matching System using Genetic Algorithm
For Chinese Character Handwriting Error Detection

Usage:
    from stroke_matcher import StrokeMatcher
    
    # Your data: list of strokes, each stroke is (k, 50) array
    written_strokes = [np.array([[x1,x2,...,x50], [y1,y2,...,y50]]), ...]
    reference_strokes = [np.array([[x1,x2,...,x50], [y1,y2,...,y50]]), ...]
    
    matcher = StrokeMatcher()
    result = matcher.match(written_strokes, reference_strokes)
    
    print(f"Best mapping: {result['mapping']}")
    print(f"Errors detected: {result['errors']}")
"""

import numpy as np
from typing import List, Tuple, Dict, Optional
from dataclasses import dataclass
from copy import deepcopy
import warnings

@dataclass
class StrokeFeatures:
    """Computed features for a single stroke"""
    center: np.ndarray  # (2,) center of mass
    length: float       # Total arc length
    angle: float        # Orientation angle from vertical
    start_point: np.ndarray  # (2,) first point
    end_point: np.ndarray    # (2,) last point
    points: np.ndarray  # (2, n) original points

class StrokeNormalizer:
    """Normalize stroke coordinates to standard space"""
    
    def __init__(self, target_size: float = 100.0):
        self.target_size = target_size
        
    def normalize(self, strokes: List[np.ndarray]) -> Tuple[List[np.ndarray], Dict]:
        """
        Normalize strokes to [0, target_size] range while preserving aspect ratio
        
        Args:
            strokes: List of (2, 50) or (k, 50) arrays where first 2 rows are x, y
            
        Returns:
            normalized_strokes: List of normalized arrays
            metadata: Dict with normalization parameters for denormalization
        """
        if len(strokes) == 0:
            return [], {}
        
        # Extract all x, y coordinates
        all_x = []
        all_y = []
        for stroke in strokes:
            if stroke.shape[0] < 2:
                raise ValueError(f"Stroke must have at least 2 rows (x, y), got shape {stroke.shape}")
            all_x.extend(stroke[0, :])
            all_y.extend(stroke[1, :])
        
        all_x = np.array(all_x)
        all_y = np.array(all_y)
        
        # Get bounding box
        x_min, x_max = all_x.min(), all_x.max()
        y_min, y_max = all_y.min(), all_y.max()
        
        # Calculate scale to fit in target_size while preserving aspect ratio
        width = x_max - x_min
        height = y_max - y_min
        
        if width == 0 and height == 0:
            scale = 1.0
        elif width == 0:
            scale = self.target_size / height
        elif height == 0:
            scale = self.target_size / width
        else:
            scale = self.target_size / max(width, height)
        
        # Normalize each stroke
        normalized = []
        for stroke in strokes:
            norm_stroke = stroke.copy()
            norm_stroke[0, :] = (stroke[0, :] - x_min) * scale
            norm_stroke[1, :] = (stroke[1, :] - y_min) * scale
            normalized.append(norm_stroke)
        
        metadata = {
            'x_min': x_min,
            'y_min': y_min,
            'x_max': x_max,
            'y_max': y_max,
            'scale': scale,
            'width': width,
            'height': height
        }
        
        return normalized, metadata

class StrokeFeatureExtractor:
    """Extract features from normalized strokes"""
    
    def extract(self, stroke: np.ndarray) -> StrokeFeatures:
        """
        Extract features from a single stroke
        
        Args:
            stroke: (2, n) or (k, n) array, uses first 2 rows as x, y
            
        Returns:
            StrokeFeatures object
        """
        x = stroke[0, :]
        y = stroke[1, :]
        
        # Center of mass
        center = np.array([x.mean(), y.mean()])
        
        # Arc length
        dx = np.diff(x)
        dy = np.diff(y)
        segment_lengths = np.sqrt(dx**2 + dy**2)
        length = segment_lengths.sum()
        
        # Angle from vertical (using start to end vector)
        start = np.array([x[0], y[0]])
        end = np.array([x[-1], y[-1]])
        vec = end - start
        
        # Angle from vertical line (pointing down: positive y direction)
        # arctan2(dx, dy) gives angle from vertical
        if np.linalg.norm(vec) > 1e-6:
            angle = np.arctan2(vec[0], vec[1])
        else:
            angle = 0.0
        
        return StrokeFeatures(
            center=center,
            length=length,
            angle=angle,
            start_point=start,
            end_point=end,
            points=stroke[:2, :]  # Store only x, y
        )

class FitnessFunction:
    """
    Multi-feature fitness function for stroke matching
    Based on paper: α·d_center + β·d_length + γ·d_angle + ε·d_relative
    """
    
    def __init__(self, alpha=1.0, beta=1.0, gamma=1.0, epsilon=1.0):
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.epsilon = epsilon
        
    def compute_distance(self, 
                        written_features: List[StrokeFeatures],
                        reference_features: List[StrokeFeatures],
                        mapping: List[int]) -> float:
        """
        Compute total distance for a given mapping
        
        Args:
            written_features: Features for written strokes
            reference_features: Features for reference strokes
            mapping: List where mapping[i] = j means written[i] maps to reference[j]
                    j=0 means no match (extra stroke)
            
        Returns:
            Total distance (lower is better)
        """
        total_distance = 0.0
        
        # Get reference bounding box top-left for relative position calculation
        if len(reference_features) > 0:
            ref_centers = np.array([f.center for f in reference_features])
            ref_bbox_tl = np.array([ref_centers[:, 0].min(), ref_centers[:, 1].min()])
        else:
            ref_bbox_tl = np.zeros(2)
        
        # Get written bounding box top-left
        if len(written_features) > 0:
            written_centers = np.array([f.center for f in written_features])
            written_bbox_tl = np.array([written_centers[:, 0].min(), written_centers[:, 1].min()])
        else:
            written_bbox_tl = np.zeros(2)
        
        for written_idx, ref_idx in enumerate(mapping):
            written_feat = written_features[written_idx]
            
            # No match (extra stroke) - high penalty
            if ref_idx == 0 or ref_idx > len(reference_features):
                total_distance += 1000.0
                continue
            
            ref_feat = reference_features[ref_idx - 1]  # mapping uses 1-indexed
            
            # 1. Center of mass distance (global feature)
            d_center = np.linalg.norm(written_feat.center - ref_feat.center)
            
            # 2. Length difference (partial feature)
            d_length = abs(written_feat.length - ref_feat.length)
            
            # 3. Angle difference (partial feature)
            d_angle = abs(written_feat.angle - ref_feat.angle)
            # Normalize angle difference to [0, pi]
            if d_angle > np.pi:
                d_angle = 2 * np.pi - d_angle
            
            # 4. Relative position distance (partial feature)
            written_rel_dist = np.linalg.norm(written_feat.center - written_bbox_tl)
            ref_rel_dist = np.linalg.norm(ref_feat.center - ref_bbox_tl)
            d_relative = abs(written_rel_dist - ref_rel_dist)
            
            # Weighted sum
            distance = (self.alpha * d_center + 
                       self.beta * d_length + 
                       self.gamma * d_angle + 
                       self.epsilon * d_relative)
            
            total_distance += distance
        
        return total_distance
    
    def compute_fitness(self, distance: float) -> float:
        """Convert distance to fitness (higher is better)"""
        return 1.0 / (1.0 + distance)

class GeneticAlgorithm:
    """
    Genetic Algorithm for stroke matching optimization
    """
    
    def __init__(self, 
                 n_written: int,
                 n_reference: int,
                 fitness_func: FitnessFunction,
                 population_size: Optional[int] = None,
                 max_generations: int = 100,
                 crossover_rate: float = 0.8,
                 mutation_rate: float = 0.1,
                 tournament_size: int = 3,
                 convergence_generations: int = 10):
        """
        Args:
            n_written: Number of written strokes
            n_reference: Number of reference strokes
            fitness_func: Fitness function to optimize
            population_size: Population size (default: 8 * n_written)
            max_generations: Maximum number of generations
            crossover_rate: Probability of crossover
            mutation_rate: Probability of mutation per gene
            tournament_size: Tournament size for selection
            convergence_generations: Stop if no improvement for this many gens
        """
        self.n_written = n_written
        self.n_reference = n_reference
        self.fitness_func = fitness_func
        self.population_size = population_size or (8 * n_written)
        self.max_generations = max_generations
        self.crossover_rate = crossover_rate
        self.mutation_rate = mutation_rate
        self.tournament_size = tournament_size
        self.convergence_generations = convergence_generations
        
        # Evolution tracking
        self.best_fitness_history = []
        self.avg_fitness_history = []
        self.best_chromosome = None
        self.best_fitness = 0.0
        
    def create_chromosome(self) -> List[int]:
        """
        Create a random chromosome (mapping)
        
        Returns:
            List of length n_written, where each value is in [0, n_reference]
            0 means no match, 1-n_reference are valid reference indices
        """
        diff = self.n_written - self.n_reference
        
        if diff == 0:
            # Equal strokes: permutation
            chromosome = list(range(1, self.n_reference + 1))
            np.random.shuffle(chromosome)
        elif diff > 0:
            # More written than reference: some map to 0 (extra strokes)
            valid_refs = list(range(1, self.n_reference + 1))
            extras = [0] * diff
            chromosome = valid_refs + extras
            np.random.shuffle(chromosome)
        else:
            # Fewer written than reference: some written may map to same reference
            chromosome = np.random.randint(1, self.n_reference + 1, size=self.n_written).tolist()
        
        return chromosome
    
    def evaluate_chromosome(self, chromosome: List[int], 
                           written_features: List[StrokeFeatures],
                           reference_features: List[StrokeFeatures]) -> float:
        """Evaluate fitness of a chromosome"""
        distance = self.fitness_func.compute_distance(
            written_features, reference_features, chromosome
        )
        return self.fitness_func.compute_fitness(distance)
    
    def tournament_selection(self, population: List[List[int]], 
                            fitnesses: List[float]) -> List[int]:
        """Select parent using tournament selection"""
        tournament_indices = np.random.choice(len(population), 
                                             self.tournament_size, 
                                             replace=False)
        tournament = [(population[i], fitnesses[i]) for i in tournament_indices]
        winner = max(tournament, key=lambda x: x[1])
        return winner[0].copy()
    
    def crossover(self, parent1: List[int], parent2: List[int]) -> Tuple[List[int], List[int]]:
        """Single-point crossover"""
        if len(parent1) < 2:
            return parent1.copy(), parent2.copy()
        
        if np.random.random() < self.crossover_rate:
            point = np.random.randint(1, len(parent1))
            child1 = parent1[:point] + parent2[point:]
            child2 = parent2[:point] + parent1[point:]
            return child1, child2
        else:
            return parent1.copy(), parent2.copy()
    
    def mutate(self, chromosome: List[int]) -> List[int]:
        """Random mutation"""
        mutated = chromosome.copy()
        for i in range(len(mutated)):
            if np.random.random() < self.mutation_rate:
                # Mutate to random valid value
                mutated[i] = np.random.randint(0, self.n_reference + 1)
        return mutated
    
    def evolve(self, written_features: List[StrokeFeatures],
               reference_features: List[StrokeFeatures]) -> Dict:
        """
        Run genetic algorithm evolution
        
        Returns:
            Dict with 'mapping', 'fitness', 'generations', 'history'
        """
        # Initialize population
        population = [self.create_chromosome() for _ in range(self.population_size)]
        
        best_chromosome = None
        best_fitness = 0.0
        generations_without_improvement = 0
        
        for generation in range(self.max_generations):
            # Evaluate fitness for all chromosomes
            fitnesses = [
                self.evaluate_chromosome(chrom, written_features, reference_features)
                for chrom in population
            ]
            
            # Track statistics
            gen_best_fitness = max(fitnesses)
            gen_avg_fitness = np.mean(fitnesses)
            self.best_fitness_history.append(gen_best_fitness)
            self.avg_fitness_history.append(gen_avg_fitness)
            
            # Update best solution (elitism)
            if gen_best_fitness > best_fitness:
                best_fitness = gen_best_fitness
                best_chromosome = population[fitnesses.index(gen_best_fitness)].copy()
                generations_without_improvement = 0
            else:
                generations_without_improvement += 1
            
            # Check convergence
            if generations_without_improvement >= self.convergence_generations:
                break
            
            # Create new population
            new_population = [best_chromosome.copy()]  # Elitism
            
            while len(new_population) < self.population_size:
                # Selection
                parent1 = self.tournament_selection(population, fitnesses)
                parent2 = self.tournament_selection(population, fitnesses)
                
                # Crossover
                child1, child2 = self.crossover(parent1, parent2)
                
                # Mutation
                child1 = self.mutate(child1)
                child2 = self.mutate(child2)
                
                new_population.extend([child1, child2])
            
            population = new_population[:self.population_size]
        
        self.best_chromosome = best_chromosome
        self.best_fitness = best_fitness
        
        return {
            'mapping': best_chromosome,
            'fitness': best_fitness,
            'generations': len(self.best_fitness_history),
            'history': {
                'best_fitness': self.best_fitness_history,
                'avg_fitness': self.avg_fitness_history
            }
        }

class ErrorDetector:
    """
    Detect writing errors from stroke matching results
    Following paper's sequential detection methodology
    """
    
    def __init__(self, angle_threshold: float = np.pi / 4):
        """
        Args:
            angle_threshold: Threshold for orientation errors (default: 45 degrees)
        """
        self.angle_threshold = angle_threshold
    
    def detect_errors(self,
                     mapping: List[int],
                     written_features: List[StrokeFeatures],
                     reference_features: List[StrokeFeatures]) -> List[Dict]:
        """
        Detect all types of errors from mapping
        
        Args:
            mapping: Best mapping from GA (written[i] -> reference[mapping[i]-1])
            written_features: Features for written strokes
            reference_features: Features for reference strokes
            
        Returns:
            List of error dictionaries with 'type', 'description', 'indices'
        """
        errors = []
        
        # Step 1: Check concatenated/redundant strokes
        errors.extend(self._check_concatenated_redundant(mapping))
        
        # Step 2: Check broken/extra strokes
        errors.extend(self._check_broken_extra(mapping))
        
        # Step 3: Check missing/incomplete strokes
        errors.extend(self._check_missing(mapping, len(reference_features)))
        
        # Step 4: Check orientation errors
        errors.extend(self._check_orientation(
            mapping, written_features, reference_features
        ))
        
        # Step 5: Check order errors
        errors.extend(self._check_order(mapping))
        
        return errors
    
    def _check_concatenated_redundant(self, mapping: List[int]) -> List[Dict]:
        """Check for concatenated or redundant strokes"""
        errors = []
        # For now, simplified check - would need sub-stroke analysis for full implementation
        return errors
    
    def _check_broken_extra(self, mapping: List[int]) -> List[Dict]:
        """Check for broken or extra strokes"""
        errors = []
        
        # Group by reference index
        ref_groups = {}
        for written_idx, ref_idx in enumerate(mapping):
            if ref_idx not in ref_groups:
                ref_groups[ref_idx] = []
            ref_groups[ref_idx].append(written_idx)
        
        # Check for extras (mapping to 0 OR multiple written mapping to same reference when we have more written strokes)
        if 0 in ref_groups and len(ref_groups[0]) > 0:
            errors.append({
                'type': 'EXTRA',
                'description': f"Extra strokes: {ref_groups[0]} (no reference match)",
                'written_indices': ref_groups[0],
                'reference_index': None
            })
        
        # Check for broken (multiple written -> one reference)
        # But only mark as broken if it's not likely an extra stroke situation
        for ref_idx, written_indices in ref_groups.items():
            if ref_idx > 0 and len(written_indices) > 1:
                # If we have more written than reference strokes, this might be extra strokes
                # manifesting as multiple mappings to same reference
                if len(mapping) > len([r for r in ref_groups if r > 0]):
                    # Mark one as correct, others as extra
                    errors.append({
                        'type': 'EXTRA',
                        'description': f"Extra stroke(s): {written_indices[1:]} (duplicate mapping to reference {ref_idx-1})",
                        'written_indices': written_indices[1:],
                        'reference_index': ref_idx - 1
                    })
                else:
                    errors.append({
                        'type': 'BROKEN',
                        'description': f"Broken stroke: written {written_indices} all map to reference {ref_idx-1}",
                        'written_indices': written_indices,
                        'reference_index': ref_idx - 1
                    })
        
        return errors
    
    def _check_missing(self, mapping: List[int], n_reference: int) -> List[Dict]:
        """Check for missing strokes"""
        errors = []
        
        # Find which reference strokes are matched
        matched_refs = set(ref_idx - 1 for ref_idx in mapping if ref_idx > 0)
        
        # Check for missing
        for ref_idx in range(n_reference):
            if ref_idx not in matched_refs:
                errors.append({
                    'type': 'MISSING',
                    'description': f"Missing stroke: reference stroke {ref_idx} not written",
                    'written_indices': None,
                    'reference_index': ref_idx
                })
        
        return errors
    
    def _check_orientation(self,
                          mapping: List[int],
                          written_features: List[StrokeFeatures],
                          reference_features: List[StrokeFeatures]) -> List[Dict]:
        """Check for orientation errors"""
        errors = []
        
        for written_idx, ref_idx in enumerate(mapping):
            if ref_idx == 0 or ref_idx > len(reference_features):
                continue
            
            written_feat = written_features[written_idx]
            ref_feat = reference_features[ref_idx - 1]
            
            angle_diff = abs(written_feat.angle - ref_feat.angle)
            if angle_diff > np.pi:
                angle_diff = 2 * np.pi - angle_diff
            
            if angle_diff > self.angle_threshold:
                errors.append({
                    'type': 'ORIENTATION',
                    'description': f"Orientation error: written stroke {written_idx} " +
                                 f"(angle {np.degrees(written_feat.angle):.1f}°) vs " +
                                 f"reference {ref_idx-1} (angle {np.degrees(ref_feat.angle):.1f}°)",
                    'written_indices': [written_idx],
                    'reference_index': ref_idx - 1,
                    'angle_diff_degrees': np.degrees(angle_diff)
                })
        
        return errors
    
    def _check_order(self, mapping: List[int]) -> List[Dict]:
        """Check for stroke order errors"""
        errors = []
        
        for written_idx, ref_idx in enumerate(mapping):
            if ref_idx > 0:
                # Expected: written_idx should match ref_idx-1 (0-indexed)
                expected_ref = written_idx + 1
                if ref_idx != expected_ref:
                    errors.append({
                        'type': 'ORDER',
                        'description': f"Order error: written stroke {written_idx} " +
                                     f"should be at position {ref_idx-1} (maps to reference {ref_idx-1})",
                        'written_indices': [written_idx],
                        'reference_index': ref_idx - 1,
                        'expected_position': ref_idx - 1
                    })
        
        return errors

class StrokeMatcher:
    """
    Complete stroke matching pipeline
    Main interface for the system
    """
    
    def __init__(self,
                 alpha: float = 1.0,
                 beta: float = 1.0,
                 gamma: float = 1.0,
                 epsilon: float = 1.0,
                 population_size: Optional[int] = None,
                 max_generations: int = 100,
                 angle_threshold: float = np.pi / 4,
                 normalize: bool = True):
        """
        Args:
            alpha, beta, gamma, epsilon: Fitness function weights
            population_size: GA population size (default: 8 * n_strokes)
            max_generations: Maximum GA generations
            angle_threshold: Threshold for orientation errors (radians)
            normalize: Whether to normalize coordinates
        """
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.epsilon = epsilon
        self.population_size = population_size
        self.max_generations = max_generations
        self.angle_threshold = angle_threshold
        self.normalize = normalize
        
        self.normalizer = StrokeNormalizer()
        self.feature_extractor = StrokeFeatureExtractor()
        self.fitness_func = FitnessFunction(alpha, beta, gamma, epsilon)
        self.error_detector = ErrorDetector(angle_threshold)
        
    def match(self, 
              written_strokes: List[np.ndarray],
              reference_strokes: List[np.ndarray],
              verbose: bool = False) -> Dict:
        """
        Complete stroke matching pipeline
        
        Args:
            written_strokes: List of (2, 50) or (k, 50) arrays (student's writing)
            reference_strokes: List of (2, 50) or (k, 50) arrays (correct template)
            verbose: Print progress information
            
        Returns:
            Dictionary containing:
                - 'mapping': Best stroke mapping (list)
                - 'fitness': Final fitness score
                - 'errors': List of detected errors
                - 'generations': Number of GA generations
                - 'written_features': Extracted written features
                - 'reference_features': Extracted reference features
                - 'normalization_metadata': Normalization parameters
        """
        if verbose:
            print(f"Matching {len(written_strokes)} written strokes to {len(reference_strokes)} reference strokes")
        
        # Step 1: Normalize coordinates
        if self.normalize:
            written_norm, written_meta = self.normalizer.normalize(written_strokes)
            reference_norm, reference_meta = self.normalizer.normalize(reference_strokes)
            if verbose:
                print(f"  Normalized to [0, 100] range")
        else:
            written_norm = written_strokes
            reference_norm = reference_strokes
            written_meta = reference_meta = {}
        
        # Step 2: Extract features
        written_features = [self.feature_extractor.extract(s) for s in written_norm]
        reference_features = [self.feature_extractor.extract(s) for s in reference_norm]
        if verbose:
            print(f"  Extracted features (center, length, angle, etc.)")
        
        # Step 3: Run genetic algorithm
        ga = GeneticAlgorithm(
            n_written=len(written_strokes),
            n_reference=len(reference_strokes),
            fitness_func=self.fitness_func,
            population_size=self.population_size,
            max_generations=self.max_generations
        )
        
        if verbose:
            print(f"  Running GA with population={ga.population_size}, max_gen={self.max_generations}")
        
        ga_result = ga.evolve(written_features, reference_features)
        
        if verbose:
            print(f"  Converged in {ga_result['generations']} generations")
            print(f"  Best fitness: {ga_result['fitness']:.4f}")
        
        # Step 4: Detect errors
        errors = self.error_detector.detect_errors(
            ga_result['mapping'],
            written_features,
            reference_features
        )
        
        if verbose:
            print(f"  Detected {len(errors)} errors")
        
        return {
            'mapping': ga_result['mapping'],
            'fitness': ga_result['fitness'],
            'errors': errors,
            'generations': ga_result['generations'],
            'history': ga_result['history'],
            'written_features': written_features,
            'reference_features': reference_features,
            'normalization_metadata': {
                'written': written_meta,
                'reference': reference_meta
            }
        }
    
    def visualize_result(self, result: Dict, written_strokes: List[np.ndarray], 
                        reference_strokes: List[np.ndarray]):
        """
        Visualize matching result (requires matplotlib)
        
        Args:
            result: Output from match()
            written_strokes: Original written strokes
            reference_strokes: Original reference strokes
        """
        try:
            import matplotlib.pyplot as plt
            from matplotlib.patches import FancyBboxPatch
        except ImportError:
            print("Matplotlib required for visualization")
            return
        
        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        
        # Plot reference
        ax = axes[0]
        ax.set_title('Reference Character', fontweight='bold')
        ax.set_aspect('equal')
        for i, stroke in enumerate(reference_strokes):
            ax.plot(stroke[0, :], stroke[1, :], linewidth=3, label=f'R{i}')
        ax.legend()
        ax.invert_yaxis()
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        
        # Plot written
        ax = axes[1]
        ax.set_title('Written Character', fontweight='bold')
        ax.set_aspect('equal')
        for i, stroke in enumerate(written_strokes):
            ax.plot(stroke[0, :], stroke[1, :], linewidth=3, label=f'W{i}')
        ax.legend()
        ax.invert_yaxis()
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        
        # Plot mapping
        ax = axes[2]
        ax.set_title(f"Mapping (Fitness: {result['fitness']:.3f})", fontweight='bold')
        ax.axis('off')
        
        mapping_text = "Stroke Mapping:\n\n"
        for i, ref_idx in enumerate(result['mapping']):
            if ref_idx == 0:
                mapping_text += f"W{i} → (no match)\n"
            else:
                mapping_text += f"W{i} → R{ref_idx-1}\n"
        
        mapping_text += f"\n\nErrors Detected ({len(result['errors'])}):\n\n"
        for error in result['errors']:
            mapping_text += f"• {error['type']}: {error['description']}\n\n"
        
        ax.text(0.1, 0.9, mapping_text, transform=ax.transAxes, 
               fontsize=10, verticalalignment='top', family='monospace')
        
        plt.tight_layout()
        plt.show()
