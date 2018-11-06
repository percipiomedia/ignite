/*
 * Licensed to the Apache Software Foundation (ASF) under one or more contributor license
 * agreements. See the NOTICE file distributed with this work for additional information regarding
 * copyright ownership. The ASF licenses this file to You under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the License. You may obtain a
 * copy of the License at http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable
 * law or agreed to in writing, software distributed under the License is distributed on an "AS IS"
 * BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 * for the specific language governing permissions and limitations under the License.
 */

package org.apache.ignite.spi.communication.tcp;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.apache.ignite.IgniteCheckedException;
import org.apache.ignite.IgniteLogger;
import org.apache.ignite.cluster.ClusterNode;
import org.apache.ignite.internal.util.IgniteUtils;
import org.apache.ignite.internal.util.lang.GridFunc;
import org.apache.ignite.resources.LoggerResource;

/**
 * {@code NodeAddressFilterTcpCommunicationSpi} is an extension of {@code TcpCommunicationSpi} which
 * filters out any {@linkplain #nodeAddresses(ClusterNode, boolean) node addresses} whose
 * {@linkplain InetAddress#getHostAddress host address} {@linkplain String#matches(String) matches}
 * any of the configured {@linkplain #getNodeAddressExclusionFilters node address exclusion
 * filters}.
 *
 * @threadsafety unsafe
 */
public class NodeAddressFilterTcpCommunicationSpi extends TcpCommunicationSpi {

   /**
    * Creates a {@code NodeAddressFilterTcpCommunicationSpi}.
    */
   public NodeAddressFilterTcpCommunicationSpi() {
      this.nodeAddressExclusionFilters = Collections.unmodifiableSet(new HashSet<>());
   }

   /**
    * Creates a {@code NodeAddressFilterTcpCommunicationSpi} with the given list of node address
    * exclusion filters.
    *
    * @pre nodeAddressExclusionFilters.stream().allMatch(f -> !f.isEmpty())
    */
   public NodeAddressFilterTcpCommunicationSpi(Set<String> nodeAddressExclusionFilters) {
      assert nodeAddressExclusionFilters.stream().allMatch(f -> !f.isEmpty());

      this.nodeAddressExclusionFilters = Collections.unmodifiableSet(nodeAddressExclusionFilters);
   }

   /**
    * Returns the regular expressions which are used to {@linkplain String#matches(String) filter
    * out} node addresses. Any address which matches any of the returned filters is not included in
    * the {@link #nodeAddresses(ClusterNode, boolean) node addresses} for a given
    * {@linkplain ClusterNode node}. The returned list is unmodifiable.
    *
    * @post return.stream().allMatch(f -> !f.isEmpty())
    */
   public Set<String> getNodeAddressExclusionFilters() {
      return this.nodeAddressExclusionFilters;
   }

   /**
    * Returns the addresses used to communicate with the given node. Addresses are returned in order
    * of preference for connection.
    *
    * @param node the node to get the addresses for
    * @param filterReachableAddresses if true, {@linkplain IgniteUtils#filterReachable un-reachable}
    *           addresses are included last in the list
    *
    * @pre node != null
    */
   @Override
   public Collection<InetSocketAddress> nodeAddresses(ClusterNode node,
      boolean filterReachableAddresses) throws IgniteCheckedException
   {
      assert node != null;

      final Collection<String> nodeIpAddresses =
         node.attribute(this.createSpiAttributeName(TcpCommunicationSpi.ATTR_ADDRS));
      final Collection<String> nodeHostNames =
         node.attribute(this.createSpiAttributeName(TcpCommunicationSpi.ATTR_HOST_NAMES));
      final Integer nodePort =
         node.attribute(this.createSpiAttributeName(TcpCommunicationSpi.ATTR_PORT));
      final Collection<InetSocketAddress> nodeExternalAddresses =
         node.attribute(this.createSpiAttributeName(TcpCommunicationSpi.ATTR_EXT_ADDRS));

      final boolean remoteAddressExists = (!GridFunc.isEmpty(nodeIpAddresses) && nodePort != null);
      final boolean externalAddressExists = !GridFunc.isEmpty(nodeExternalAddresses);

      if (!remoteAddressExists && !externalAddressExists) {
         throw new IgniteCheckedException(
            "Failed to send message to the destination node. Node doesn't have any " +
               "TCP communication addresses or mapped external addresses. Check configuration and make sure " +
               "that you use the same communication SPI on all nodes. Remote node id: " + node.id());
      }

      LinkedHashSet<InetSocketAddress> addresses;

      // Try to connect first on bound addresses.
      if (remoteAddressExists) {
         final List<InetSocketAddress> addressList =
            new ArrayList<>(IgniteUtils.toSocketAddresses(nodeIpAddresses, nodeHostNames, nodePort));

         final boolean sameHost = IgniteUtils.sameMacs(this.getSpiContext().localNode(), node);
         Collections.sort(addressList, IgniteUtils.inetAddressesComparator(sameHost));

         addresses = new LinkedHashSet<>(addressList);
      }
      else {
         addresses = new LinkedHashSet<>();
      }

      // Then on mapped external addresses.
      if (externalAddressExists) {
         addresses.addAll(nodeExternalAddresses);
      }

      if (this.log.isDebugEnabled()) {
         this.log.debug("Addresses resolved from attributes [rmtNode=" + node.id() + ", addrs=" +
            addresses + ", isRmtAddrsExist=" + remoteAddressExists + ']');
      }

      if (filterReachableAddresses) {
         final Set<InetAddress> allInetAddresses = IgniteUtils.newHashSet(addresses.size());

         for (final InetSocketAddress address : addresses) {
            // Skip unresolved as address.getAddress() can return null.
            if (!address.isUnresolved()) {
               allInetAddresses.add(address.getAddress());
            }
         }

         final List<InetAddress> reachableInetAddrs = IgniteUtils.filterReachable(allInetAddresses);

         if (reachableInetAddrs.size() < allInetAddresses.size()) {
            final LinkedHashSet<InetSocketAddress> addresslist =
               IgniteUtils.newLinkedHashSet(addresses.size());

            final List<InetSocketAddress> unreachableInetAddress =
               new ArrayList<>(allInetAddresses.size() - reachableInetAddrs.size());

            for (final InetSocketAddress address : addresses) {
               if (reachableInetAddrs.contains(address.getAddress())) {
                  addresslist.add(address);
               }
               else {
                  unreachableInetAddress.add(address);
               }
            }

            addresslist.addAll(unreachableInetAddress);
            addresses = addresslist;
         }

         if (this.log.isDebugEnabled()) {
            this.log.debug(
               "Addresses to connect for node [rmtNode=" + node.id() + ", addrs=" + addresses + ']');
         }
      }

      // Apply the configured node address exclusion filters.
      final Iterator<InetSocketAddress> addressIterator = addresses.iterator();
      while (addressIterator.hasNext()) {
         final InetSocketAddress address = addressIterator.next();
         for (final String filter : this.getNodeAddressExclusionFilters()) {
            if (address.getAddress().getHostAddress().matches(filter)) {
               addressIterator.remove();
               break;
            }
         }
      }

      return addresses;
   }

   /**
    * The logger injected by Ignite.
    */
   @LoggerResource
   private IgniteLogger log;

   private final Set<String> nodeAddressExclusionFilters;
}
